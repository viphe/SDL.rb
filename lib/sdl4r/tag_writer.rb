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
  # Forward-only, non-cached SDL writer to Tag structure.
  #
  class TagWriter
    require 'sdl4r/abstract_writer'
    
    include AbstractWriter
    
    # Used to discriminate an unprovided parameter from +nil+.
    # @private
    MISSING_PARAMETER = Object.new # :nodoc:

    # @overload [Tag]
    # @overload [Tag, ObjectMapper]
    # @overload [ObjectMapper]
    #
    # @param [Tag] root tag (written data is added to this Tag)
    # @param [ObjectMapper] object_mapper used during serialization operations
    #
    def initialize(root = nil, object_mapper = ObjectMapper.new)
      root, object_mapper = nil, root if root.is_a? ObjectMapper
      root = Tag.new(SDL4R::ROOT_TAG_NAME) unless root

      self.object_mapper = object_mapper

      @root = root
      @stack = [ root ]
    end
    
    attr_reader :root
    
    # Returns the current contextual Tag (== root, at creation).
    # Returns nil if there is no more context.
    #
    def current
      @stack.last
    end

    def depth
      @stack.length - 1
    end
    
    def start_element(namespace, name = nil, &block)
      namespace, name = '', namespace unless name

      name ||= SDL4R::ROOT_TAG_NAME

      child = current.new_child(namespace, name)
      @stack << child

      if block_given?
        block[self]
        end_element
      else
        child
      end
    end
    alias_method :start_tag, :start_element
    
    def end_element
      @stack.pop
    end
    alias_method :end_tag, :end_element

    def start_body
    end
    
    def end_body
    end
    
    def attribute(namespace, name, value = MISSING_PARAMETER)
      tag = current
      if value === MISSING_PARAMETER
        tag.set_attribute(namespace, name)
      else
        tag.set_attribute(namespace, name, value)
      end
      tag
    end
    
    def value(*values)
      tag = current
      tag.values = *values
      tag
    end
  end
end
