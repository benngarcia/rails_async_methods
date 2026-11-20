# frozen_string_literal: true

require "test_helper"

class SignatureTest < Minitest::Test
  class Targets
    def no_args; end
    def req_and_opt(a, b = 1, c = 2); end
    def post_req(a, b = 1, c); end
    def with_rest(a, *rest, z); end
    def with_kwargs(a:, b: 2); end
    def with_keyrest(a:, **kw); end
    def anon_rest(*); end
    def anon_keyrest(**); end
    def anon_block(&); end
    def forward(...); end
    def nokey(*args, **nil); end
    def destruct((a, b)); end
    def ignored(_, _); end
    def hash_opt(opts = {}); end

    def r2k(*args); end
    ruby2_keywords :r2k
  end

  def setup
    @t = Targets.new
  end

  def validate(name, *args, **kwargs)
    RailsAsyncMethods::Signature.validate!(@t.method(name), args, kwargs)
  end

  def test_no_args
    assert_equal [[], {}], validate(:no_args)
    assert_raises(ArgumentError) { validate(:no_args, 1) }
    assert_raises(ArgumentError) { validate(:no_args, a: 1) }
  end

  def test_req_and_opt_preserves_omitted_defaults
    assert_equal [[1], {}], validate(:req_and_opt, 1)
    assert_equal [[1, 2], {}], validate(:req_and_opt, 1, 2)
    assert_equal [[1, 2, 3], {}], validate(:req_and_opt, 1, 2, 3)
    assert_raises(ArgumentError) { validate(:req_and_opt) }
    assert_raises(ArgumentError) { validate(:req_and_opt, 1, 2, 3, 4) }
  end

  def test_post_req_and_rest
    assert_equal [[1, 2], {}], validate(:post_req, 1, 2)
    assert_equal [[1, 2, 3], {}], validate(:post_req, 1, 2, 3)
    assert_raises(ArgumentError) { validate(:post_req, 1) }

    assert_equal [[1, 2], {}], validate(:with_rest, 1, 2)
    assert_equal [[1, 2, 3, 4], {}], validate(:with_rest, 1, 2, 3, 4)
    assert_raises(ArgumentError) { validate(:with_rest, 1) }
  end

  def test_kwargs_and_keyrest
    assert_equal [[], { a: 1 }], validate(:with_kwargs, a: 1)
    assert_equal [[], { a: 1, b: 9 }], validate(:with_kwargs, a: 1, b: 9)
    err = assert_raises(ArgumentError) { validate(:with_kwargs) }
    assert_match(/missing keyword: :a/, err.message)

    err = assert_raises(ArgumentError) { validate(:with_kwargs, a: 1, typo: 2) }
    assert_match(/unknown keyword: :typo/, err.message)

    assert_equal [[], { a: 1, extra: 2 }], validate(:with_keyrest, a: 1, extra: 2)
  end

  def test_modern_ruby3_anonymous_and_forwarding_forms
    assert_equal [[1, 2], {}], validate(:anon_rest, 1, 2)
    assert_equal [[{ a: 1 }], {}], validate(:anon_rest, a: 1)
    assert_equal [[], { a: 1, b: 2 }], validate(:anon_keyrest, a: 1, b: 2)
    assert_equal [[], {}], validate(:anon_block)
    assert_equal [[1, 2], { a: 3 }], validate(:forward, 1, 2, a: 3)
    assert_equal [[1, 2], { a: 3 }], validate(:r2k, 1, 2, a: 3)
  end

  def test_nokey_rejects_keywords
    assert_equal [[1, 2], {}], validate(:nokey, 1, 2)
    err = assert_raises(ArgumentError) { validate(:nokey, 1, a: 2) }
    assert_match(/no keywords accepted/, err.message)
  end

  def test_destructuring_and_repeated_underscores
    assert_equal [[[1, 2]], {}], validate(:destruct, [1, 2])
    assert_equal [["first", "second"], {}], validate(:ignored, "first", "second")
  end

  def test_trailing_keyword_folds_into_positional_hash_when_target_accepts_no_kwargs
    assert_equal [[{ foo: :bar }], {}], validate(:hash_opt, foo: :bar)
    assert_equal [[], {}], validate(:hash_opt)
  end
end
