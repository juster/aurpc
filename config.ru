# -*- ruby -*-

require './aurpc.rb'

use Rack::Config do |env|
  env.merge!({ 'SCRIPT_NAME' => '/aurpc',
               'HTTP_HOST'   => 'juster.us',
               'HTTP_PORT'   => 80 })
end

run Sinatra::Application
