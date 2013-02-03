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

  # Used internally by SDL readers for keeping track of their state.
  class Element

    attr_accessor :self_closing
    attr_reader :name, :prefix, :attributes, :values, :children

    def initialize(prefix, name)
      @prefix = prefix
      @name = name
      @attributes = []
      @values = []
      @children = []
      @child_index = 0
      @self_closing = false
    end

    def add_attribute(prefix, name, value)
      @attributes << [prefix, name, value]
    end

    # @return the value of the specified attribute
    def attribute(prefix, name = nil)
      if name
        prefix, name = prefix.to_s, name.to_s
      else
        prefix, name = '', prefix.to_s
      end

      attributes.each do |attr|
        return attr[2] if attr[0] == prefix && attr[1] == name
      end

      nil
    end

    #  @return the attribute at the specified index: <code>[namespace, name, value]</code>.
    def attribute_at(index)
      attributes[index]
    end

    def attribute_count
      attributes.size
    end

    def attributes?
      attributes.length > 0
    end

    def add_value(*values)
      @values.concat(values)
    end
    alias_method :add_values, :add_value

    def add_all_values(enumerable)
      if enumerable.is_a? Array
        @values.concat(enumerable)
      else
        enumerable.each { |item| @values << item }
      end
    end

    def add_child(prefix, name, child)
      @children << [prefix, name, child]
    end

    def next_child
      if @child_index < @children.length
        child = @children[@child_index]
        @child_index += 1
        child
      else
        nil
      end
    end

    self.freeze
  end
end
