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

# Work-around a bug in NetBeans (http://netbeans.org/bugzilla/show_bug.cgi?id=188653)
if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  $:[0] = File.join(File.dirname(__FILE__),'../../../lib')
  $:.unshift(File.join(File.dirname(__FILE__),'../../../test'))
end

if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

module SDL4R
  module Parser

    require 'stringio'
    require 'test/unit'

    require 'sdl4r/tag'
    require 'sdl4r/tokenizer'

    require 'sdl4r/sdl_test_case'


    class TokenizerTest < Test::Unit::TestCase
      include SdlTestCase

      # Fully tokenizes 's' and returns an array of the found token types plus an array of the found
      # tokens
      #
      def tokenize(s)
        tokenizer = Tokenizer.new(StringIO.new(s))
        token_types = []
        tokens = []
        
        while tokenizer.read
          token_types << tokenizer.token_type
          tokens << tokenizer.token
        end

        assert_equal :EOF, token_types.last
        assert_equal nil, tokens.last

        token_types.pop
        tokens.pop

        return token_types, tokens
      end
      private :tokenize

      def test_backquote_strings
        types, tokens = tokenize("``")
        assert_equal [:INLINE_BACKQUOTE_STRING], types
        assert_equal [""], tokens

        types, tokens = tokenize("` `")
        assert_equal [:INLINE_BACKQUOTE_STRING], types
        assert_equal [" "], tokens

        types, tokens = tokenize("`abc\\\ndef`")
        assert_equal(
          [:MULTILINE_BACKQUOTE_STRING_START, :MULTILINE_BACKQUOTE_STRING_END], types)
        assert_equal ["abc\\\n", "def"], tokens

        types, tokens = tokenize("`abc\\\n  def`")
        assert_equal(
          [:MULTILINE_BACKQUOTE_STRING_START, :MULTILINE_BACKQUOTE_STRING_END], types)
        assert_equal ["abc\\\n", "  def"], tokens

        types, tokens = tokenize("`\ndef`")
        assert_equal(
          [:MULTILINE_BACKQUOTE_STRING_START, :MULTILINE_BACKQUOTE_STRING_END], types)
        assert_equal ["\n", "def"], tokens

        types, tokens = tokenize("`abc\n  def \n ghi`")
        assert_equal [
          :MULTILINE_BACKQUOTE_STRING_START,
          :MULTILINE_BACKQUOTE_STRING_PART,
          :MULTILINE_BACKQUOTE_STRING_END],
          types
        assert_equal ["abc\n", "  def \n", " ghi"], tokens


        types, tokens = tokenize("`abc\n  def \n ghi\n`")
        assert_equal [
          :MULTILINE_BACKQUOTE_STRING_START,
          :MULTILINE_BACKQUOTE_STRING_PART,
          :MULTILINE_BACKQUOTE_STRING_PART,
          :MULTILINE_BACKQUOTE_STRING_END],
          types
        assert_equal ["abc\n", "  def \n", " ghi\n", ""], tokens
      end

      def test_double_quote_string
        types, tokens = tokenize('""')
        assert_equal [:INLINE_DOUBLE_QUOTE_STRING], types
        assert_equal [""], tokens

        types, tokens = tokenize('"tutu"')
        assert_equal [:INLINE_DOUBLE_QUOTE_STRING], types
        assert_equal ["tutu"], tokens

        types, tokens = tokenize('"\\t"')
        assert_equal [:INLINE_DOUBLE_QUOTE_STRING], types
        assert_equal ["\\t"], tokens
      end
    end
  end
end