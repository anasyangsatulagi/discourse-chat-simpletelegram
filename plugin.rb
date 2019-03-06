# name: discourse-chat-simpletelegram
# about: Strip down version of official telegram support for discourse-chat-integration
# version: 0.1
# url: https://github.com/anasyangsatulagi/discourse-chat-simpletelegram
# author: e1

enabled_site_setting :chat_integration_simpletelegram_enabled

after_initialize do
  require_relative "../discourse-chat-integration/app/initializers/discourse_chat"

  # Register a module under DiscourseChat::Provider which ends in the word "Provider"
  module DiscourseChat::Provider::SimpletelegramProvider
        PROVIDER_NAME = "simpletelegram".freeze
        PROVIDER_ENABLED_SETTING = :chat_integration_simpletelegram_enabled
        CHANNEL_PARAMETERS = [
          { key: "name", regex: '^\S+' },
          { key: "chat_id", regex: '^(-?[0-9]+|@\S+)$', unique: true }
        ]

        def self.sendMessage(message)
          return self.do_api_request('sendMessage', message)
        end
  
        def self.do_api_request(methodName, message)
          http = Net::HTTP.new("api.telegram.org", 443)
          http.use_ssl = true
  
          access_token = SiteSetting.chat_integration_simpletelegram_access_token
  
          uri = URI("https://api.telegram.org/bot#{access_token}/#{methodName}")
  
          req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
          req.body = message.to_json
          response = http.request(req)
  
          responseData = JSON.parse(response.body)
  
          return responseData
        end

        def self.message_text(post)
          display_name = "@#{post.user.username}"
          full_name = post.user.name || ""
  
          if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0) && (full_name.strip.gsub(' ', '').casecmp(post.user.username) != 0)
            display_name = "#{full_name} @#{post.user.username}"
          end
  
          topic = post.topic
  
          category = ''
          if topic.category
            category = (topic.category.parent_category) ? "[#{topic.category.parent_category.name}/#{topic.category.name}]" : "[#{topic.category.name}]"
          end
  
          tags = ''
          if topic.tags.present?
            tags = topic.tags.map(&:name).join(', ')
          end
  
          return I18n.t(
              "chat_integration.provider.simpletelegram.message",
              user: display_name,
              post_url: post.full_url,
              title: CGI::escapeHTML(topic.title),
              post_excerpt: post.excerpt(SiteSetting.chat_integration_simpletelegram_excerpt_length, text_entities: true, strip_links: true, remap_emoji: true),
            )
        end

        def self.trigger_notification(post, channel)
          chat_id = channel.data['chat_id']
  
          message = {
            chat_id: chat_id,
            text: message_text(post),
            parse_mode: "html",
            disable_web_page_preview: true,
          }
  
          response = sendMessage(message)
  
          if response['ok'] != true
            error_key = nil
            if response['description'].include? 'chat not found'
              error_key = 'chat_integration.provider.simpletelegram.errors.channel_not_found'
            elsif response['description'].include? 'Forbidden'
              error_key = 'chat_integration.provider.simpletelegram.errors.forbidden'
            end
            raise ::DiscourseChat::ProviderError.new info: { error_key: error_key, message: message, response_body: response }
          end
        end
      
  end

end