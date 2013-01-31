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

  require 'stringio'
  require 'test/unit'

  require 'sdl4r/sdl4r'
  require 'sdl4r/reader'

  require 'sdl4r/sdl_test_case'

  class ReaderTest < Test::Unit::TestCase
    include SdlTestCase

    def read(sdl)
      node_types = []
      node_values = []
      Reader.from_memory(sdl).each { |node|
        node_types << node.node_type
        node_values << node.value if node.node_type == Reader::TYPE_ELEMENT
      }
      return node_types, node_values
    end
    private :read

    def test_read_empty
      reader = Reader.from_memory("")
      assert_nil reader.read
    end

    def test_read_values
      types, values = read("tag1 `toto`")
      assert_equal [Reader::TYPE_ELEMENT], types
      assert_equal [["toto"]], values

      types, values = read("tag1 \"toto\"")
      assert_equal [Reader::TYPE_ELEMENT], types
      assert_equal [["toto"]], values

      types, values = read("tag1 \"toto\\t123\"")
      assert_equal [Reader::TYPE_ELEMENT], types
      assert_equal [["toto\t123"]], values

      types, values = read(<<-EOS)
      tag1 {
        "text"
        tag2 123
      }
      EOS
      assert_equal(
        [Reader::TYPE_ELEMENT, Reader::TYPE_ELEMENT, Reader::TYPE_ELEMENT, Reader::TYPE_END_ELEMENT],
        types)
      assert_equal [nil, ["text"], [123]], values
    end

    def test_accessors
      reader = Reader.from_memory(<<-EOS)
      tag1 "I've seen this before."
      tag2 party="today" ever:work=false {
        ns:tag3 "time is of the essence" attr1=-145.99
        "Taratatata"
        tag4
      }
      EOS

      node = reader.read
      assert_equal Reader::TYPE_ELEMENT, node.node_type
      assert_equal "", node.prefix
      assert_equal "tag1", node.name
      assert_equal true, node.self_closing?
      assert_equal ["I've seen this before."], node.value
      assert_equal ["I've seen this before."], node.values
      assert_equal true, node.value?
      assert_equal true, node.values?
      assert_equal false, node.attributes?
      assert_equal 0, node.attribute_count
      assert_equal [], node.attributes
      assert_equal nil, node.attribute("something")

      node = reader.read
      assert_equal Reader::TYPE_ELEMENT, node.node_type
      assert_equal "", node.prefix
      assert_equal "tag2", node.name
      assert_equal false, node.self_closing?
      assert_equal nil, node.values
      assert_equal false, node.values?
      assert_equal true, node.attributes?
      assert_equal 2, node.attribute_count
      assert_equal [[["", "party"], "today"], [["ever", "work"], false]], node.attributes
      assert_equal [["", "party"], "today"], node.attribute_at(0)
      assert_equal [["ever", "work"], false], node.attribute_at(1)
      assert_equal "today", node.attribute("party")
      assert_equal false, node.attribute("ever", "work")
      assert_equal nil, node.attribute("work")

      node = reader.read
      assert_equal Reader::TYPE_ELEMENT, node.node_type
      assert_equal "ns", node.prefix
      assert_equal "tag3", node.name
      assert_equal true, node.self_closing?
      assert_equal ["time is of the essence"], node.values
      assert_equal true, node.values?
      assert_equal true, node.attributes?
      assert_equal 1, node.attribute_count
      assert_equal [[["", "attr1"], -145.99]], node.attributes
      assert_equal [["", "attr1"], -145.99], node.attribute_at(0)
      assert_equal(-145.99, node.attribute("attr1"))
      assert_equal(-145.99, node.attribute("", "attr1"))
      assert_equal nil, node.attribute("kraken", "attr1")

      node = reader.read
      assert_equal Reader::TYPE_ELEMENT, node.node_type
      assert_equal "", node.prefix
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, node.name
      assert_equal true, node.self_closing?
      assert_equal ["Taratatata"], node.value
      assert_equal true, node.value?
      assert_equal false, node.attributes?
      assert_equal 0, node.attribute_count
      assert_equal [], node.attributes

      node = reader.read
      assert_equal Reader::TYPE_ELEMENT, node.node_type
      assert_equal "", node.prefix
      assert_equal "tag4", node.name
      assert_equal true, node.self_closing?
      assert_equal nil, node.value
      assert_equal false, node.value?
      assert_equal false, node.attributes?
      assert_equal 0, node.attribute_count
      assert_equal [], node.attributes

      node = reader.read
      assert_equal Reader::TYPE_END_ELEMENT, node.node_type

      assert_nil reader.read
      assert_nil reader.read
    end
  end

end