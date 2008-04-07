require "#{File.dirname(__FILE__)}/../test_helper"

class OpenidUserStoriesTest < ActionController::IntegrationTest
  fixtures :all

  def test_verifying_identifier_ownership
    claimed_id = "http://www.example.com/quentin"
    request_params = checkid_request_params.merge(
      'openid.identity' => claimed_id,
      'openid.claimed_id' => claimed_id)
    # OpenID requests comes in
    post '/server', request_params 
    # User has to log in
    assert_redirected_to login_url
    post '/session', :login => 'quentin', :password => 'test'
    # User has to verify the request
    assert_redirected_to proceed_url
    follow_redirect!
    assert_redirected_to decide_url
    follow_redirect!
    assert_template 'server/decide'
    post 'server/complete', :temporary => 1
    assert @response.redirect_url_match?(checkid_request_params['openid.return_to'])
    assert @response.redirect_url_match?(/mode=id_res/)
  end
  
  def test_providing_sreg_data
    claimed_id = "http://www.example.com/quentin"
    request_params = checkid_request_params.merge(
      'openid.identity' => claimed_id,
      'openid.claimed_id' => claimed_id).merge(
      sreg_request_params)
    # OpenID requests comes in
    post '/server', request_params 
    # User has to log in
    assert_redirected_to login_url
    post '/session', :login => 'quentin', :password => 'test'
    # User has to verify the request
    assert_redirected_to proceed_url
    follow_redirect!
    assert_redirected_to decide_url
    follow_redirect!
    assert_template 'server/decide'
    post 'server/complete', :temporary => 1, 
      :site => { :properties => { 'nickname' => 'Test' } }
    assert @response.redirect_url_match?(checkid_request_params['openid.return_to'])
    assert @response.redirect_url_match?(/openid\.mode=id_res/)
    assert @response.redirect_url_match?(/openid\.sreg\.nickname=Test/)
  end

  def test_responding_to_immidiate_requests_when_already_logged_in
    claimed_id = "http://www.example.com/quentin"
    request_params = checkid_request_params.merge(
      'openid.mode' => 'checkid_immediate',
      'openid.identity' => claimed_id,
      'openid.claimed_id' => claimed_id)
    # User will be logged in when the request comes in
    post '/session', :login => 'quentin', :password => 'test'
    post '/server', request_params
    # Request has to be answered directly
    assert_redirected_to proceed_url
    follow_redirect!
    assert @response.redirect_url_match?(checkid_request_params['openid.return_to'])
    assert @response.redirect_url_match?(/mode=id_res/)
  end

  def test_trusting_a_site_and_responding_with_the_stored_release_policy_on_subsequent_requests
    @account = accounts(:standard)
    @persona = @account.personas.first
    claimed_id = "http://www.example.com/#{@account.login}"
    request_params = checkid_request_params.merge(
      'openid.identity' => claimed_id,
      'openid.claimed_id' => claimed_id).merge(
      sreg_request_params)
    # User will be logged in when the request comes in
    post '/session', :login => @account.login, :password => 'test'
    post '/server', request_params
    # User verifies the request and stores the details for this site
    assert_redirected_to proceed_url
    follow_redirect!
    assert_redirected_to decide_url
    follow_redirect!
    assert_template 'server/decide'
    post 'server/complete', :always => 1, :site => { 
      :persona_id => @persona.id,
      :url => checkid_request_params['openid.trust_root'],
      :properties => { 'nickname' => @persona.nickname } }
    assert @response.redirect_url_match?(checkid_request_params['openid.return_to'])
    assert @response.redirect_url_match?(/openid\.mode=id_res/)
    assert @response.redirect_url_match?(/openid\.sreg\.nickname=#{@persona.nickname}/)
    # Has the site been saved?
    assert_not_nil @account.sites.find_by_url(checkid_request_params['openid.trust_root'])
    # Now comes the second request
    post '/server', request_params
    assert_redirected_to proceed_url
    follow_redirect!
    assert @response.redirect_url_match?(/mode=id_res/)
    assert @response.redirect_url_match?(/openid\.sreg\.nickname=#{@persona.nickname}/)
  end
end