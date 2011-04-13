require 'test/unit'

require 'git-svn-clone-externals'

# no need to support old style (1.4) externals
#OLD_INPUT = "# /
#third-party/sounds             http://svn.example.com/repos/sounds
#third-party/skins -r148        http://svn.example.com/skinproj
#third-party/skins/toolkit -r21 http://svn.example.com/skin-maker
#"

TEST_CASES = [
  { :input => "/^/trunk/tools@4001  ext-src/tools", 
    :repo => "http://example.com/svn",
    :exp_url => "http://example.com/svn/trunk/tools", 
    :exp_dir => "ext-src/tools", :exp_rev => "4001" },
    
  { :input => "/https://example.com/svn/trunk/tools  ext-src/tools", 
    :repo => "https://example.com/svn",
    :exp_url => "https://example.com/svn/trunk/tools", 
    :exp_dir => "ext-src/tools", :exp_rev => nil },

  { :input => "/-r 3001 ^/trunk/tools/A  ext-src/A", 
    :repo => "https://example.com/svn",
    :exp_url => "https://example.com/svn/trunk/tools/A", 
    :exp_dir => "ext-src/A", :exp_rev => "3001" },
]

INPUT = "
# /
/^/trunk/tools/NTService@42476  ext-tools/NTService
/^/trunk/shared/build@42751  shared/build
/^/trunk/shared/include/cxxtest@42751  shared/include/cxxtest
"

class TestExtParse < Test::Unit::TestCase
  # def setup
  # end

  # def teardown
  # end

  def test_invalid_input
    result = parse_externals("# /", "DUMMY")
    assert_equal(0, result.length)
  end       

  def test_inputs
    TEST_CASES.each do |tc|
      result = parse_externals(tc[:input], tc[:repo])
      #puts tc[:input]
      #puts result.length, result
      assert_equal(1, result.length)
      assert_equal(tc[:exp_url], result[0][:url])
      assert_equal(tc[:exp_dir], result[0][:dir])
      assert_equal(tc[:exp_rev], result[0][:rev])
    end
  end

  def test_basic_input
    result = parse_externals(INPUT, "DUMMY")
    #puts result
    assert_equal(3, result.length)
    # TODO: check output!
    
  end
end


# TODO: test cases for url resolution

class TestUrlResolution < Test::Unit::TestCase
  def test_caret
    result = resolve_url("^/dirA/dirB", "dummy", "https://example.com/svn")
    assert_equal("https://example.com/svn/dirA/dirB", result)
  end
end
