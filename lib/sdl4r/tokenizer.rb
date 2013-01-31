#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
# Simple Declarative Language (SDL) for Ruby
# Copyright 2005 Ikayzo, inc.
#
# This program is free software. You can distribute or modify it under the
# terms of the GNU Lesser General Public License version 2.1 as published by
# the Free Software Foundation.
#
# This program is distributed AS IS and WITHOUT WARRANTY. OF ANY KIND,
# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++

module SDL4R

  require 'strscan'

  require 'sdl4r/sdl_parse_error'
  require 'sdl4r/token'

  # Tokenizer for SDL.
  #
  # As Ruby's IO standard libraries are not so much low-level, this class works on lines. This
  # means that some token types reflect this line-oriented tokenizing.
  #
  # The other solution would be to implement a proper tokenizer natively, which I don't feel like
  # doing right now.
  #
  #--
  # FIXME: implement a way of stacking the errors without raising an error immediately
  #++
  #
  class Tokenizer # :nodoc: all

    class Matcher # :nodoc: all
      def initialize(token_type, regex, options = {}, &block)
        options = {
          :next_mode => nil,
          :push_back_eol => false,
          :error => nil,
        }.merge(options)

        @token_type = token_type
        @regex = regex
        @next_mode = options[:next_mode]
        @push_back_eol = options[:push_back_eol]
        @error = options[:error]

        if block_given?
          instance_eval(&block)
        end
      end
      attr_reader :token_type, :regex, :next_mode

      # Indicates whether the matched token tends to match the end of line character and whether
      # it should be pushed back in this cases.
      attr_reader :push_back_eol

      # If +nil+, this Matcher is normal, otherwise it is meant to detect errors and this
      # returns a message.
      attr_reader :error

      # Called when a token is found in order to remove meaningless characters, etc.
      def process_token(token)
        token
      end

      self.freeze
    end

    # A string used at the end of each line in order to trigger the EOL token.
    # @private
    @@EOL_STRING = "\n"

    # @private
    @@matcher_sets = {
      :top => [
        Matcher.new(:EOL, /\A\n/),
        Matcher.new(:WHITESPACE, /\A\s+/, :push_back_eol => true),
        Matcher.new(:SEMICOLON, /\A;/),
        Matcher.new(:COLON, /\A:/),
        Matcher.new(:EQUAL, /\A=/),
        Matcher.new(:BLOCK_START, /\A\{/),
        Matcher.new(:BLOCK_END, /\A\}/),
        Matcher.new(:BOOLEAN, /\Atrue|false|on|off/),
        Matcher.new(:NULL, /\Anull/),
        Matcher.new(:ONE_LINE_COMMENT, /\A(?:#|--|\/\/).*\Z/, :push_back_eol => true) do
          def process_token(token)
            token.gsub!(/\A(?:#|--|\/\/)/, "")
          end
        end,
        Matcher.new(:INLINE_COMMENT, /\A\/\*[\s\S]*?\*\//) do
          def process_token(token)
            token.gsub!(/\A\/\*|\*\/\Z/, "")
          end
        end,
        Matcher.new(
          :MULTILINE_COMMENT_START,
          /\A\/\*.*\Z/,
          :next_mode => :multiline_comment,
          :push_back_eol => true) do
          def process_token(token)
            token.gsub!(/\A\/\*/, "")
          end
        end,
        Matcher.new(:CHARACTER, /\A'(?:[^\\']|\\.)'/) do
          def process_token(token)
            token.gsub!(/\A'|'\Z/, "")
          end
        end,
        Matcher.new(:INLINE_BACKQUOTE_STRING, /\A`[^`]*`/, :is_node => true) do
          def process_token(token)
            token.gsub!(/\A`|`\Z/, "")
          end
        end,
        Matcher.new(:INLINE_DOUBLE_QUOTE_STRING, /\A"(?:[^\\"]|\\.)*"/) do
          def process_token(token)
            token.gsub!(/\A"|"\Z/, "")
          end
        end,
        Matcher.new(
          :MULTILINE_BACKQUOTE_STRING_START,
          /\A`[^`]*\Z/,
          :next_mode => :multiline_backquote_string,
          :is_node => true) do
            def process_token(token)
              token.gsub!(/\A`/, "")
            end
          end,
        Matcher.new(
          :MULTILINE_DOUBLE_QUOTE_STRING_START,
          /\A"(?:[^\\"]|\\\S)*\\\s*\Z/,
          :next_mode => :multiline_double_quote_string,
          :push_back_eol => true) do
            def process_token(token)
              token.gsub!(/\A"|\\\s*\Z/, "")
            end
          end,
        Matcher.new(:INLINE_BINARY, /\A\[[\sA-Za-z0-9\/=\+]*\]/) do
            def process_token(token)
              token.gsub!(/\A\[|\s+|\]\Z/, "")
            end
          end,
        Matcher.new(
          :MULTILINE_BINARY_START, /\A\[[\sA-Za-z0-9\/=\+]*\Z/,
          :next_mode => :multiline_binary,
          :push_back_eol => true) do
            def process_token(token)
              token.gsub!(/\A\[|\s+/, "")
            end
          end,
        Matcher.new(
          :IDENTIFIER, /\A#{SDL4R::IDENTIFIER_START_CLASS}#{SDL4R::IDENTIFIER_PART_CLASS}*/),
        Matcher.new(:DATE, /\A-?\d+\/\d+\/\d+/, :is_node => true),
        Matcher.new(
          :TIME_OR_TIMESPAN,
          /\A(?:-?\d+d:)?-?\d+:\d+(?::\d+(?:\.\d+)?)?
            (?:-[a-zA-Z\/]+(?:[+-]\d+(?::\d+)?)?)?/ix),
        Matcher.new(:INTEGER, /\A[\+\-]?\d+L/i), # takes precedence on floats
        # the float regex is meant to also catch bad syntaxed floats like "1.2.2" (otherwise, we
        # would not detect this kind of errors easily).
        Matcher.new(
          :FLOAT, /\A[\+\-]?(?:\d+(?:F|D|BD)|\d*\.[\d\.]+(?:F|D|BD)?)/i),
        Matcher.new(:INTEGER, /\A[\+\-]?\d+L?/i),
        Matcher.new(:LINE_CONTINUATION, /\A\\\s*\Z/), # outside of comments, strings, etc
        Matcher.new(
          :UNCLOSED_DOUBLE_QUOTE_STRING,
          /\A"(?:[^\\"]|\\\S)*/,
          :error => "unclosed string"),
      ],

      :multiline_comment => [
        Matcher.new(:EOL, /\A\n/),
        Matcher.new(:MULTILINE_COMMENT_END, /\A[\s\S]*?\*\//, :next_mode => :top) do
          def process_token(token)
            token.gsub!(/\*\/\Z/, "")
          end
        end,
        Matcher.new(:MULTILINE_COMMENT_PART, /\A.+\Z/, :push_back_eol => true)
      ],

      :multiline_backquote_string => [
        Matcher.new(:EOL, /\A\n/),
        Matcher.new(:MULTILINE_BACKQUOTE_STRING_END, /\A[^`]*`/, :next_mode => :top) do
          def process_token(token)
            token.gsub!(/`\Z/, "")
          end
        end,
        Matcher.new(:MULTILINE_BACKQUOTE_STRING_PART, /\A[^`]*\Z/)
      ],

      :multiline_double_quote_string => [
        Matcher.new(:EOL, /\A\n/),
        Matcher.new(
          :MULTILINE_DOUBLE_QUOTE_STRING_END, /\A(?:[^\\"]|\\\S)*"/, :next_mode => :top) do
            def process_token(token)
              token.gsub!(/\A\s+|"\Z/, "")
            end
          end,
        Matcher.new(
          :MULTILINE_DOUBLE_QUOTE_STRING_PART,
          /\A(?:[^\\"]|\\\S)*\\\s*\Z/,
          :push_back_eol => true) do
            def process_token(token)
              token.gsub!(/\A\s+|\\\s*\Z/, "")
            end
          end,
        Matcher.new(
          :UNCLOSED_DOUBLE_QUOTE_STRING,
          /\A(?:[^\\"]|\\\S)*\Z/,
          :error => "unclosed multiline string")
      ],

      :multiline_binary => [
        Matcher.new(:EOL, /\A\n/),
        Matcher.new(:MULTILINE_BINARY_END, /\A[\sA-Za-z0-9\/=\+]*\]/, :next_mode => :top) do
          def process_token(token)
            token.gsub!(/\s+|\]\Z/, "")
          end
        end,
        Matcher.new(:MULTILINE_BINARY_PART, /\A[\sA-Za-z0-9\/=\+]*\Z/, :push_back_eol => true) do
          def process_token(token)
            token.gsub!(/\s+/, "")
          end
        end
      ]
    }

    # @param [IO] the IO to read from
    # @raise [ArgumentError] if +io+ is +nil+.
    def initialize io
      raise ArgumentError, 'io' unless io
      @io = io
      @scanner = nil
      @line_no = -1
      set_mode(:top)

      @token = nil
      @pushed_back_token = nil
      @previous_token = nil

      @token_pool = [] # a pool of reusable Tokens
    end

    # @return [String] text of the current token.
    def token
      @token.text
    end

    # @return [Symbol] type of the current token (e.g. +:WHITESPACE+)
    def token_type
      @token.type
    end

    # @return [Integer] position of the current token (only meant for error tracking for the time
    #   being)
    def token_line_no
      @token.line_no
    end

    # @return [Integer] position of the current token (only meant for error tracking for the time
    #   being)
    def token_pos
      @token.pos
    end

    # Sets the current working mode of this Tokenizer.
    #
    # @param [Symbol] new mode
    #   * +:top+ (normal default mode)
    #   * +:multiline_comment+
    #   * +:multiline_backquote_string+
    #   * +:multiline_double_quote_string+
    #   * +:multiline_binary+
    #
    # @return [self]
    # @raise [ArgumentError] if the given mode is unknown.
    #
    def set_mode(mode)
      ms = @@matcher_sets[mode]
      raise ArgumentError, "unknown tokenizer mode #{mode.to_s}" unless ms
      @matcher_set = ms
      self
    end

    # Reads a token from the pushed back ones.
    def read_pushed_back
      record_previous_token

      # Set the current state
      @token = @pushed_back_token
      @pushed_back_token = nil

      if @token.matcher
        next_mode = @token.matcher.next_mode
        set_mode(next_mode) if next_mode
      end
    end
    private :read_pushed_back

    # Goes to the next token.
    #
    # @return [Symbol] +nil+ if eof has been reached, the current token type otherwise.
    #
    def read
      if @pushed_back_token
        read_pushed_back
        return @token.type
      end

      record_previous_token
      @token = nil

      if @line_no < 0 or @scanner.eos? # fetch a line if beginning or at end of line
        unless read_line
          if previous_token_type == :EOF
            return nil
          else
            @token = Token.new(nil, :EOF, nil, @line_no, @scanner ? @scanner.pos : 0)
            return @token.type
          end
        end
      end

      pos = @scanner.pos
      @matcher_set.each do |matcher|
        if token_text = @scanner.scan(matcher.regex)
          error = matcher.error
          if error
            raise_parse_error(error)

          else
            set_matcher_token(matcher, token_text, pos)
            if matcher.push_back_eol and @scanner.eos?
              @scanner.pos = @scanner.pos - @@EOL_STRING.size
            end
          end
          break
        end
      end

      raise_unexpected_char unless @token

      return @token.type
    end

    def record_previous_token
      @previous_token = @token
    end
    private :record_previous_token

    # Sets the current Token using the Matcher that detected it
    def set_matcher_token(matcher, token_text, pos)
      @token = Token.new(
        matcher.process_token(token_text), matcher.token_type, matcher, @line_no, pos)

      next_mode = matcher.next_mode
      set_mode(next_mode) if next_mode
    end
    private :set_matcher_token

    # @return [Symbol] the type of the previous Token.
    def previous_token_type
      @previous_token ? @previous_token.type : nil
    end

    # Unreads the current token.
    # The previous token becomes the current one
    #
    # @raise if #unread has been called twice in a row (no call to #read)
    def unread
      if @pushed_back_token
        raise "only one token can be pushed back"
      else
        @pushed_back_token = @token
        @token = @previous_token

        # We have no memory of what happened before
        @previous_token = nil

        if @token.matcher
          next_mode = @token.matcher.next_mode
          set_mode(next_mode) if next_mode
        end
      end
    end

    # Raises a standard "unexpected character" error.
    def raise_unexpected_char(msg = "unexpected char")
      raise_parse_error "#{msg}: <#{@scanner.peek(1)}>"
    end

    def raise_parse_error(msg = "parse error", line_no = @line_no, pos = @scanner.pos)
      line = (line_no == @line_no)? @scanner.string : nil
      raise SdlParseError.new(msg, line_no + 1, pos + 1, line)
    end

    private

    # Reads the next line of the IO.
    # All lines are normalized to end with a single '\n'.
    #
    # @return [String] the new read line.
    #
    def read_line
      line = @io.gets

      if line
        # Clean the line of its end characters
        line.gsub!(/(?:\n|\r\n|\r)\Z/, @@EOL_STRING)

        @line_no += 1

        if @scanner
          @scanner.string = line
        else
          @scanner = StringScanner.new(line)
        end
      end

      line
    end
  end
end
