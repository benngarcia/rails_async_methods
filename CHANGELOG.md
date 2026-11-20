# Changelog

## 1.0.0 (Rewrite Reference Branch)

Complete from-scratch rewrite addressing all security, metaprogramming, ActiveJob, and packaging issues found in `0.2.x`:

- **Security**: Removed `module_eval` / `binding.local_variable_get` (eliminating parameter-shadowing RCE and code injection). Enforced strict method allowlists at both enqueue time and perform time. Validated `job:` subclasses against `ActiveJob::Base`.
- **Ruby 3.3+ Semantics**: Replaced `ParameterParser` with pure `Signature` validation using `Method#parameters` — preserves default argument values, supports `*`, `**`, `&`, `...`, `**nil`, destructuring, and `ruby2_keywords`, and loudly rejects blocks.
- **Zero Global Pollution**: Removed `Object#async` and `Object#to_active_job` monkey-patches; moved to explicit `include RailsAsyncMethods` + `BasicObject` proxy (`target.async(opts).method_name`).
- **Modern Rails (7.2 / 8.0+)**: Enabled `enqueue_after_transaction_commit` by default, added `ClassTargetSerializer` for class methods and stateless services, added `async_job` for `ActiveJob.perform_all_later`, added Zeitwerk-safe string job references, removed the required generator, and narrowed gemspec dependencies to `activejob`, `activesupport`, and `globalid`.

## 0.2.2

- Fixed frozen string literal warning on zero-argument `async` methods.

## 0.2.1

- Fixed `:wait` scheduling calculation.

## 0.2.0

- Added `Object#async` / `Object#to_active_job` wrapper.

## 0.1.0

- Initial release.
