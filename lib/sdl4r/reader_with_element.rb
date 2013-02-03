#!/usr/bin/env ruby -w
# encoding: UTF-8

module SDL4R

  require 'sdl4r/element'

  # Utility Module allowing implementing methods of AbstractReader related to the current element.
  #
  #   class MyReader < AbstractReader
  #     include ReaderWithElement
  #
  #     def element
  #       return @current_element # instance of Element
  #     end
  #
  #   end
  #
  module ReaderWithElement

    def prefix
      e = element
      e ? e.prefix : nil
    end

    def name
      e = element
      e ? e.name : nil
    end

    def attributes
      e = element
      e ? e.attributes : []
    end

    def attribute(prefix, name = nil)
      e = element
      e ? e.attribute(prefix, name) : nil
    end

    def attribute_at(index)
      e = element
      e ? e.attribute_at(index) : nil
    end

    def attribute_count
      e = element
      e ? e.attribute_count : 0
    end

    def attributes?
      e = element
      e ? e.attributes? : false
    end

    def values
      e = element
      e ? e.values : nil
    end

    def values?
      e = element
      e ? e.values.count > 0 : false
    end

    def self_closing?
      e = element
      e ? e.self_closing : false
    end

  end
end
