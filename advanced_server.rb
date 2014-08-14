require 'sinatra'
require 'rest_client'
require 'json'
require 'typhoeus'

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['CLIENT_SECRET']

use Rack::Session::Cookie, :secret => rand.to_s()

def authenticated?
  session[:access_token]
end

def authenticate!
  erb :index, :locals => {:client_id => CLIENT_ID}
end

get '/' do
  if !authenticated?
    authenticate!
  else
    access_token = session[:access_token]
    scopes = []

    begin
      auth_result = RestClient.get('https://api.github.com/user',
                                   {:params => {:access_token => access_token},
                                    :accept => :json})
    rescue => e
      # request didn't succeed because the token was revoked so we
      # invalidate the token stored in the session and render the
      # index page so that the user can start the OAuth flow again

      session[:access_token] = nil
      return authenticate!
    end
    t1 = Time.now
    puts t1
    # the request succeeded, so we check the list of current scopes
    if auth_result.headers.include? :x_oauth_scopes
      scopes = auth_result.headers[:x_oauth_scopes].split(', ')
    end

    auth_result = JSON.parse(auth_result)

    if scopes.include? 'user:email'
      auth_result['private_emails'] =
          JSON.parse(RestClient.get('https://api.github.com/user/emails',
                                    {:params => {:access_token => access_token},
                                     :accept => :json}))
    end

    #erb :advanced, :locals => auth_result
    redirect '/repos'
  end
end

get '/callback' do
  session_code = request.env['rack.request.query_hash']['code']

  result = RestClient.post('https://github.com/login/oauth/access_token',
                           {:client_id => CLIENT_ID,
                            :client_secret => CLIENT_SECRET,
                            :code => session_code},
                           :accept => :json)

  session[:access_token] = JSON.parse(result)['access_token']

  redirect '/'
end

get '/repos' do
  #content_type :json
  access_token = session[:access_token]

  repos = RestClient.get('https://api.github.com/user/repos',
                         {:params => {:access_token => access_token},
                          :accept => :json})
  hash = JSON.parse(repos)

  languages, language_obj = getLanguageCount(hash)

  language_bytes, language_byte_count = getLanguageBytes(hash, language_obj)
  t2 = Time.now
  puts t2
  erb :lang_freq, :locals => { :languages => languages.to_json, :language_byte_count => language_bytes.to_json}
end

def getLanguageCount(repoHash)
  language_obj = {}
  repoHash.each do |repo|
    # sometimes language can be nil
    lang = repo['language']
    if lang
      if !language_obj[lang]
        language_obj[lang] = 1
      else
        language_obj[lang] += 1
      end
    end
  end

  languages = []
  language_obj.each do |lang, count|
    languages.push :name => lang, :count => count
  end

  puts languages
  return languages, language_obj
end

def getLanguageBytes(repoHash, language_obj)
  hydra = Typhoeus::Hydra.hydra
  access_token = session[:access_token]
  language_byte_count = []

  repoHash.each do |repo|
    puts "URL: #{repo['languages_url']}"

    request = Typhoeus::Request.new(repo['languages_url'],
                                    headers: {ContentType: "application/json"},
                                    params: {:access_token => access_token})
    request.on_complete do |response|
      repo_langs = response.response_body
      langHash = JSON.parse(repo_langs)

      puts langHash

      if !langHash.empty?
        langHash.each do |key, value|
          puts "Repo Lang: #{key} value: #{value}"
          if !language_obj[key]
            language_obj[key] = value
          else
            language_obj[key] += value
          end
        end
      end
    end

    hydra.queue request
  end

  # this is a blocking call that returns once all requests are complete
  hydra.run

  language_obj.each do |lang, count|
     language_byte_count.push :name => "#{lang} (#{count})", :count => count
  end

  #some mandatory formatting for d3
  language_bytes = [ :name => "language_bytes", :elements => language_byte_count]
  puts language_bytes
  return language_bytes, language_byte_count
end