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
  # Used internally by Reader for keeping track of its state.
  # It shouldn't be used directly as it is subject to changes as Reader is modified.
  class Element

    attr_accessor :self_closing
    attr_reader :name, :prefix, :attributes, :values

    def initialize(prefix, name)
      @prefix = prefix
      @name = name
      @attributes = []
      @values = []
      @self_closing = false
    end

    def add_attribute(prefix, name, value)
      @attributes << [[prefix, name], value]
    end

    def add_value(value)
      @values << value
    end

    self.freeze
  end
end
