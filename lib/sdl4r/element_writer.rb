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

  require 'sdl4r/abstract_writer'

  # ElementWriter is similar to a TagWriter but allows to mix Element, regular objects and Tags together in the
  # same document. It is meant to be used within AbstractReaders and requires an ObjectReader to read the resulting
  # objects properly.
  #
  # If you need to build a pure object hierarchy, use an ObjectWriter instead.
  #
  # @attr_reader [Element] root root element of the object hierarchy built by this ElementWriter
  #
  class ElementWriter
    require 'sdl4r/abstract_writer'
    include AbstractWriter

    attr_reader :root

    # @param root [Element] the root Element to build upon (defaults to )
    def initialize(root = Element.new('', SDL4R::ANONYMOUS_TAG_NAME))
      raise 'root must be an Element' unless root.is_a? Element
      @root = root
      @stack = [@root]
    end

    def current
      @stack.last
    end
    protected :current

    def start_element(namespace, name = nil)
      if name.nil?
        namespace, name = nil, namespace.to_s
      else
        namespace, name = namespace.to_s, name.to_s
      end

      started = Element.new(namespace, name)
      current.add_child(namespace, name, started)
      @stack << started

      self
    end

    def end_element
      @stack.pop
      self
    end

    def start_body
      current.self_closing = false
      self
    end

    def end_body
      self
    end

    def value(*values)
      current.add_values(*values)
      self
    end

    def attribute(namespace, name, value = MISSING_PARAMETER)
      if value == MISSING_PARAMETER
        namespace, name, value = nil, namespace.to_s, name
      else
        namespace, name = namespace.to_s, name.to_s
      end

      current.add_attribute(namespace, name, value)
      self
    end

    def write_impl(namespace, name, o)
      current.add_child(namespace, name, o)
      self
    end
    protected :write_impl

  end
end