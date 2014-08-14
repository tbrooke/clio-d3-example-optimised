require 'sinatra'
require 'rest-client'
require 'json'

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['CLIENT_SECRET']

get '/' do
  erb :index, :locals => {:client_id => CLIENT_ID}
end

get '/callback' do
  # get temporary GitHub code...
  session_code = request.env['rack.request.query_hash']['code']

  # ... and POST it back to GitHub
  result = RestClient.post('https://github.com/login/oauth/access_token',
                           {:client_id => CLIENT_ID,
                            :client_secret => CLIENT_SECRET,
                            :code => session_code},
                            :accept => :json)

  # extract the token and granted scopes
  access_token = JSON.parse(result)['access_token']
  scopes = JSON.parse(result)['scope'].split(',')




  # check if we were granted user:email scope
  has_user_email_scope = scopes.include? 'user:email'


  # fetch user information
  auth_result = JSON.parse(RestClient.get('https://api.github.com/user',
                                          {:params => {:access_token => access_token},
                                           :accept => :json}))

  # if the user authorized it, fetch private emails
  if has_user_email_scope
    auth_result['private_emails'] =
      JSON.parse(RestClient.get('https://api.github.com/user/emails',
                                {:params => {:access_token => access_token},
                                 :accept => :json}))
      end

  erb :basic, :locals => auth_result
end
