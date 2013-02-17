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
  
  # A do-nothing SDL writer (it will still go through the given blocks though).
  #
  class NilWriter
    include AbstractWriter

    def initialize(object_mapper = ObjectMapper.new)
      self.object_mapper = object_mapper
      @depth = 0
    end
    attr_reader :depth
    
    def start_element(namespace, name = nil)
      @depth += 1
    end

    def start_tag(namespace, name = nil)
      start_element(namespace, name)
    end
    
    def end_element
      @depth -= 1
    end

    def end_tag
      end_element
    end

    def start_body
    end
    
    def end_body
    end

    def attribute(namespace, name, value = MISSING_PARAMETER)
    end

    def value(*values)
    end
  end
end
