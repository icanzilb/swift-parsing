/// A parser that attempts to run another parser as many times as specified, accumulating the result
/// of the outputs.
///
/// For example, given a comma-separated string of numbers, one could parse out an array of
/// integers:
///
/// ```swift
/// var input = "1,2,3"[...]
/// let output = Many(Int.parser(), separator: ",").parse(&input)
/// precondition(input == "")
/// precondition(output == [1, 2, 3])
/// ```
///
/// The most general version of `Many` takes a closure that can customize how outputs accumulate,
/// much like `Sequence.reduce(into:_)`. We could, for example, sum the numbers as we parse them
/// instead of accumulating each value in an array:
///
/// ```
/// let sumParser = Many(
///   Int.parser(of: Substring.self),
///   into: 0,
///   separator: StartsWith(","),
///   +=
/// )
/// var input = "1,2,3"[...]
/// let output = Many(Int.parser(), into: 0, separator: ",").parse(&input)
/// precondition(input == "")
/// precondition(output == 6)
/// ```
public struct Many<Upstream, Result, Separator>: Parser
where
  Upstream: Parser,
  Separator: Parser,
  Upstream.Input == Separator.Input
{
  @Environment(\.maximum) public var maximum
  @Environment(\.minimum) public var minimum
  @Environment(\.skipSpaces) public var skipSpaces
  public let initialResult: Result
  public let separator: Separator?
  public let updateAccumulatingResult: (inout Result, Upstream.Output) -> Void
  public let upstream: Upstream

  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - upstream: Another parser.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - separator: A parser that consumes input between each parsed output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the upstream parser.
  @inlinable
  public init(
    _ upstream: Upstream,
    into initialResult: Result,
    separator: Separator,
    _ updateAccumulatingResult: @escaping (inout Result, Upstream.Output) -> Void
  ) {
    self.initialResult = initialResult
    self.separator = separator
    self.updateAccumulatingResult = updateAccumulatingResult
    self.upstream = upstream
  }

  @inlinable
  public func parse(_ input: inout Upstream.Input) -> Result? {
    let original = input
    var rest = input
    var result = self.initialResult
    var count = 0
    if self.skipSpaces {
      _trimSpacePrefix(&input)
    }

    let upstreamParse = { (input: inout Upstream.Input) -> Upstream.Output? in
      if self.skipSpaces {
        _trimSpacePrefix(&input)
      }
      return self.upstream
        .environment(\.maximum, .max)
        .environment(\.minimum, 0)
        .parse(&input)
    }
    let separatorParse = { (input: inout Separator.Input) -> Separator.Output? in
      if self.skipSpaces {
        _trimSpacePrefix(&input)
      }
      return self.separator?.parse(&input)
    }

    while count < self.maximum, let output = upstreamParse(&input) {
      count += 1
      rest = input
      self.updateAccumulatingResult(&result, output)
      if self.separator != nil, separatorParse(&input) == nil {
        guard count >= self.minimum else {
          input = original
          return nil
        }
        return result
      }
    }
    input = rest
    guard count >= self.minimum else {
      input = original
      return nil
    }
    return result
  }
}

extension Many where Result == [Upstream.Output], Separator == Always<Input, Void> {
  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs in an array.
  ///
  /// - Parameters:
  ///   - upstream: Another parser.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  @inlinable
  public init(
    _ upstream: Upstream
  ) {
    self.init(upstream, into: []) {
      $0.append($1)
    }
  }
}

extension Many where Result == [Upstream.Output] {
  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs in an array.
  ///
  /// - Parameters:
  ///   - upstream: Another parser.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - separator: A parser that consumes input between each parsed output.
  @inlinable
  public init(
    _ upstream: Upstream,
    separator: Separator
  ) {
    self.init(upstream, into: [], separator: separator) {
      $0.append($1)
    }
  }
}

extension Many where Separator == Always<Input, Void> {

  /// Initializes a parser that attempts to run the given parser at least and at most the given
  /// number of times, accumulating the outputs into a result with a given closure.
  ///
  /// - Parameters:
  ///   - upstream: Another parser.
  ///   - minimum: The minimum number of times to run this parser and consider parsing to be
  ///     successful.
  ///   - maximum: The maximum number of times to run this parser before returning the output.
  ///   - updateAccumulatingResult: A closure that updates the accumulating result with each output
  ///     of the upstream parser.
  @inlinable
  public init(
    _ upstream: Upstream,
    into initialResult: Result,
    _ updateAccumulatingResult: @escaping (inout Result, Upstream.Output) -> Void
  ) {
    self.initialResult = initialResult
    self.separator = nil
    self.updateAccumulatingResult = updateAccumulatingResult
    self.upstream = upstream
  }
}

extension Parsers {
  public typealias Many = Parsing.Many  // NB: Convenience type alias for discovery
}
