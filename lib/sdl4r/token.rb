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
  # Used internally by Tokenizer for keeping track of its state.
  # Don't use directly.
  # @private
  class Token

    def initialize(text, type, matcher, line_no, pos)
      @text = text
      @type = type
      @matcher = matcher
      @line_no = line_no
      @pos = pos
    end

    # Line number of the token
    attr_accessor :line_no
    # Position of the token in the line
    attr_accessor :pos
    # Type of token (e.g. :WHITESPACE)
    attr_accessor :type
    # Matcher object associated that discovered this Token
    attr_accessor :matcher
    # The token text
    attr_accessor :text

    self.freeze
  end
end

