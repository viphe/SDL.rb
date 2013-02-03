#!/usr/bin/env ruby -w
# encoding: UTF-8

module SDL4R

  require 'sdl4r/abstract_reader'
  require 'sdl4r/object_mapper'
  require 'sdl4r/element'
  require 'sdl4r/reader_with_element'

  # An reader that turns object graphs into a SDL stream as per SDL serialization.
  #
  class ObjectReader < AbstractReader
    include ReaderWithElement

    # @param root root of the object graph to read from
    # @param object_mapper [ObjectMapper]
    #
    def initialize(root, object_mapper = ObjectMapper.new)
      @root = root
      @object_mapper = object_mapper
      @stack = []
      @node_type = nil
      @eof_reached = false

      record_object_graph
    end

    # Reads the whole graph once in order to determine the minimal amount of object ids.
    def record_object_graph
      @object_mapper.start_recording
      each { } # go through the whole graph
      @object_mapper.stop_recording
      rewind
    end
    private :record_object_graph

    def rewindable?
      true
    end

    def rewind
      @node_type = nil
      @stack.clear
      @eof_reached = false
    end

    # Returns the currently traversed Element or nil if none is.
    def element
      @stack.last
    end
    private :element

    # Enters the specified object as a SDL element. The current node type becomes TYPE_ELEMENT.
    #
    def enter_object(prefix, name, object)
      @node_type = TYPE_ELEMENT
      @stack << Element.new(prefix, name)

      if @object_mapper.collection?(object)
        enter_collection(prefix, name, object)

      elsif SDL4R::is_coercible?(object)
        element.add_value(object)

      else
        # handle repetitions of objects
        ref = @object_mapper.reference_object(object)
        if ref.multi_ref?
          if ref.count == 1
            if depth == 0
              # can't have an attribute in the root object, so we use an ad hoc child
              element.add_child(@object_mapper.element_namespace, @object_mapper.oid_attr, ref.oid)
            else
              element.add_attribute(@object_mapper.attribute_namespace, @object_mapper.oid_attr, ref.oid)
            end
          else
            element.add_attribute(@object_mapper.attribute_namespace, @object_mapper.oref_attr, ref.oid)
            element.self_closing = true
            return # make sure we don't loop in the graph
          end
        end

        @object_mapper.each_property(object) do |prop_namespace, prop_name, value, type|
          type = :element if type == :attribute and depth == 0 # no attribute at root level

          case type
            when :element
              element.add_child(prop_namespace, prop_name, value)
            when :attribute
              element.add_attribute(prop_namespace, prop_name, value)
            else
              # ignore
          end
        end
      end

      element.self_closing = element.children.empty? # any object without sub-objects is considered self-closing
    end
    private :enter_object

    def enter_collection(prefix, name, collection)
      if depth > 0 and collection.all? { |item| SDL4R::is_coercible?(item) }
        element.add_all_values(collection)
      else
        collection.each { |item|
          element.add_child('', SDL4R::ANONYMOUS_TAG_NAME, item)
        }
      end
    end
    private :enter_collection

    def node_type
      @node_type
    end

    def depth
      @stack.length - 1
    end

    def read
      if @root.nil?
        @eof_reached = true
      end

      return nil if @eof_reached

      if @stack.empty?
        enter_object('', SDL4R::ROOT_TAG_NAME, @root)

      else
          if @node_type == TYPE_END_ELEMENT # current element already closed
            @stack.pop
            if @stack.empty?
              @eof_reached = true
              return nil
            end
          end

          next_child = element.next_child
          if next_child.nil?
            @node_type = TYPE_END_ELEMENT # close current element
          else
            enter_object(*next_child)
          end
      end

      self
    end

  end
end