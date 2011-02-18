require 'state_machine'
require 'has_messages/has_uuid'

# Adds a generic implementation for sending messages between users
module HasMessages
  module MacroMethods
    # Creates the following message associations:
    # * +messages+ - Messages that were composed and are visible to the owner.
    #   Mesages may have been sent or unsent.
    # * +received_messages - Messages that have been received from others and
    #   are visible.  Messages may have been read or unread.
    # 
    # == Creating new messages
    # 
    # To create a new message, the +messages+ association should be used,
    # for example:
    # 
    #   user = User.find(123)
    #   message = user.messages.build
    #   message.subject = 'Hello'
    #   message.body = 'How are you?'
    #   message.to User.find(456)
    #   message.save
    #   message.deliver
    # 
    # == Drafts
    # 
    # You can get the drafts for a particular user by using the +unsent_messages+
    # helper method.  This will find all messages in the "unsent" state.  For example,
    # 
    #   user = User.find(123)
    #   user.unsent_messages
    # 
    # You can also get at the messages that *have* been sent, using the +sent_messages+
    # helper method.  For example,
    # 
    #  user = User.find(123)
    #  user.sent_messages
    def has_messages
      has_many  :messages,
                  :as => :sender,
                  :class_name => 'Message',
                  :conditions => {:hidden_at => nil},
                  :order => 'messages.created_at DESC'
      has_many  :received_messages,
                  :as => :receiver,
                  :class_name => 'MessageRecipient',
                  :include => :message,
                  :conditions => ['message_recipients.hidden_at IS NULL AND messages.state = ?', 'sent'],
                  :order => 'messages.created_at DESC'
#      has_many  :received_message_threads,
#                  :as => :receiver,
#                  :class_name => 'MessageRecipient',
#                  :include => :message,
#                  :conditions => ['message_recipients.hidden_at IS NULL AND messages.state = ? and messages.original_message_id IS NOT NULL', 'sent'],
#                  :group => 'messages.original_message_id',
#                  :order => 'messages.created_at DESC'

      include HasMessages::InstanceMethods
    end
  end
  
  module InstanceMethods
    # Composed messages that have not yet been sent.  These consists of all
    # messages that are currently in the "unsent" state.
    def unsent_messages
      messages.with_state(:unsent)
    end
    
    # Composed messages that have already been sent.  These consists of all
    # messages that are currently in the "queued" or "sent" states.
    def sent_messages
      messages.with_states(:queued, :sent)
    end

    # Returns the most recent message of each thread
    def last_received_message_per_thread
      MessageRecipient.find_all_by_receiver_id(id, :order => 'id desc', :joins => :message, :conditions => 'message_recipients.hidden_at is null', :group => 'COALESCE(original_message_id,messages.id)')
    end
    
    def conversations
      (messages + received_messages.map(&:message)).compact.uniq
    end

    def original_conversations
      conversations.select{ |message| message.original_message_id == nil }
    end

    def find_conversation_by_id(id)
      conversations.select{ |message| message.id == id.to_i }.first
    end

    def unread_messages
      received_messages.select(&:unread?).map(&:message)
    end
  end
end

ActiveRecord::Base.class_eval do
  extend HasMessages::MacroMethods
end

require 'has_messages/models/message.rb'
require 'has_messages/models/message_recipient.rb'
