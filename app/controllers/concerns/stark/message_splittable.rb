module Stark
  module MessageSplittable
    extend ActiveSupport::Concern

    MAX_MESSAGE_LENGTH = ENV.fetch('MAX_MESSAGE_LENGTH', 32).to_i

    def split_messages(content)
      return [content] if content.length <= MAX_MESSAGE_LENGTH

      messages = []
      start_index = 0

      while start_index < content.length
        chunk, new_start_index = get_next_chunk(content, start_index)
        messages << chunk.strip
        start_index = new_start_index
      end

      messages
    end

    private

    # Handles getting the next chunk of text
    def get_next_chunk(content, start_index)
      chunk = content[start_index, MAX_MESSAGE_LENGTH]
      new_start_index = start_index + MAX_MESSAGE_LENGTH

      return [chunk, new_start_index] if last_chunk?(content, start_index) || next_char_is_space?(content, start_index)
      
      handle_word_boundary(chunk, start_index)
    end

    # Handles word boundaries to prevent splitting words
    def handle_word_boundary(chunk, start_index)
      last_space = chunk.rindex(' ')
      
      if last_space
        [chunk[0..last_space], start_index + last_space + 1]
      else
        [chunk, start_index + MAX_MESSAGE_LENGTH]
      end
    end

    def last_chunk?(content, start_index)
      start_index + MAX_MESSAGE_LENGTH >= content.length
    end

    def next_char_is_space?(content, start_index)
      content[start_index + MAX_MESSAGE_LENGTH] == ' '
    end
  end
end
