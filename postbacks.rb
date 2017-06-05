require 'facebook/messenger'
include Facebook::Messenger

TYPE_LOCATION = [{content_type: 'location'}]

Facebook::Messenger::Profile.set({
  setting_type: 'call_to_actions',
  thread_state: 'new_thread',
  call_to_actions: [
    {
      payload: 'START'
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

# Create persistent menu
Facebook::Messenger::Profile.set({
  setting_type: 'call_to_actions',
  thread_state: 'existing_thread',
  call_to_actions: [
    {
      type: 'postback',
      title: 'Get coordinates',
      payload: 'COORDINATES'
    },
    {
      type: 'postback',
      title: 'Get full address',
      payload: 'FULL_ADDRESS'
    },
    {
      type: 'postback',
      title: 'Location lookup',
      payload: 'LOCATION'
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

# Set greeting (for first contact)
Facebook::Messenger::Profile.set({
  setting_type: 'greeting',
  greeting: [
    {
      locale: 'default',
      text: 'Welcome to your new Guigui bot !'
    },
    {
      locale: 'fr_FR',
      text: 'Bienvenue dans le bot de Guigui!'
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

Bot.on :postback do |postback|
  sender_id = postback.sender['id']
  case postback.payload
  when 'START' then show_replies_menu(postback.sender['id'], MENU_REPLIES)
  when 'COORDINATES'
    say(sender_id, IDIOMS[:ask_location], TYPE_LOCATION)
    show_coordinates(sender_id)
  when 'FULL_ADDRESS'
    say(sender_id, IDIOMS[:ask_location], TYPE_LOCATION)
    show_full_address(sender_id)
  when 'LOCATION'
    lookup_location(sender_id)
  end
end
