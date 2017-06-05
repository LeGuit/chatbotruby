require 'facebook/messenger'
require 'httparty'
require 'json'
require 'dotenv/load'

require_relative 'idioms'
require_relative 'menu_replies'
require_relative 'postbacks'

include Facebook::Messenger
# NOTE: ENV variables should be set directly in terminal for testing on localhost

# Subcribe bot to your page
Facebook::Messenger::Subscriptions.subscribe(access_token: ENV["ACCESS_TOKEN"])

TYPE_LOCATION = [{content_type: 'location'}]

API_URL = 'https://maps.googleapis.com/maps/api/geocode/json?address='
REVERSE_API_URL = 'https://maps.googleapis.com/maps/api/geocode/json?latlng='

def say(recipient_id, text, quick_replies = nil)
  message_options = {
  recipient: { id: recipient_id },
  message: { text: text }
  }
  if quick_replies
    message_options[:message][:quick_replies] = quick_replies
  end
  Bot.deliver(message_options, access_token: ENV['ACCESS_TOKEN'])
end

def wait_for_command
  Bot.on :message do |message|
    puts "Received '#{message.inspect}' from #{message.sender}" # debug only
    sender_id = message.sender['id']
    case message.text
    when /coord/i, /gps/i
      say(sender_id, IDIOMS[:ask_location], TYPE_LOCATION)
      show_coordinates(sender_id)
    when /full ad/i # we got the user even the address is misspelled
      say(sender_id, IDIOMS[:ask_location], TYPE_LOCATION)
      show_full_address(sender_id)
    when /location/i
      lookup_location(sender_id)
    else
      message.reply(text: IDIOMS[:unknown_command])
      show_replies_menu(sender_id, MENU_REPLIES)
    end
  end
end

def wait_for_any_input
  Bot.on :message do |message|
    show_replies_menu(message.sender['id'], MENU_REPLIES)
  end
end

def lookup_location(sender_id)
  say(sender_id, 'Let me know your location:', TYPE_LOCATION)
  Bot.on :message do |message|
    if message_contains_location?(message)
      handle_user_location(message)
    else
      message.reply(text: "Please try your request again and use 'Send location' button")
    end
    wait_for_any_input
  end
end

def message_contains_location?(message)
  if attachments = message.attachments
    attachments.first['type'] == 'location'
  else
    false
  end
end

def handle_user_location(message)
  coords = message.attachments.first['payload']['coordinates']
  lat = coords['lat']
  long = coords['long']
  message.typing_on
  parsed = get_parsed_response(REVERSE_API_URL, "#{lat},#{long}")
  address = extract_full_address(parsed)
  message.reply(text: "Coordinates of your location: Latitude #{lat}, Longitude #{long}. Looks like you're at #{address}")
  wait_for_any_input
end

def show_replies_menu(id, quick_replies)
  say(id, IDIOMS[:menu_greeting], quick_replies)
  wait_for_command
end

def show_coordinates(id)
  Bot.on :message do |message|
    if message_contains_location?(message)
      handle_user_location(message)
    else
      handle_coordinates_lookup(message, id)
    end
  end
end

def handle_coordinates_lookup(message, id)
  query = encode_ascii(message.text)
  parsed_response = get_parsed_response(API_URL, query)
  message.typing_on
  if parsed_response
    coord = extract_coordinates(parsed_response)
    text = "Latitude: #{coord['lat']} / Longitude: #{coord['lng']}"
    say(id, text)
    wait_for_any_input
  else
    message.reply(text: IDIOMS[:not_found])
    show_coordinates(id)
  end
end

def show_full_address(id)
  Bot.on :message do |message|
    if message_contains_location?(message)
      handle_user_location(message)
      wait_for_any_input
    else
      handle_address_lookup(message, id)
    end
  end
end

def handle_address_lookup(message, id)
  query = encode_ascii(message.text)
  parsed_response = get_parsed_response(API_URL, query)
  message.typing_on
  if parsed_response
    full_address = extract_full_address(parsed_response)
    say(id, full_address)
    wait_for_any_input
  else
    message.reply(text: IDIOMS[:not_found])
    show_full_address(id)
  end
end

def extract_full_address(parsed)
  parsed['results'].first['formatted_address']
end

def get_parsed_response(url, query)
  response = HTTParty.get(url + query)
  parsed = JSON.parse(response.body)
  parsed['status'] != 'ZERO_RESULTS' ? parsed : nil
end

def encode_ascii(s)
  Addressable::URI.parse(s).normalize.to_s
end

def is_text_message?(message)
  !message.text.nil?
end
# Look inside the hash to find coordinates
def extract_coordinates(parsed)
  parsed['results'].first['geometry']['location']
end

wait_for_any_input
