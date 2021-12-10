private enum SkipSpacesKey: ParserEnvironmentKey {
  static var value = false
}

extension ParserEnvironmentValues {
  public var skipSpaces: Bool {
    get { self[SkipSpacesKey.self] }
    set { self[SkipSpacesKey.self] = newValue }
  }
}

extension Parsers {
  public struct SkipSpaces<Upstream>: Parser where Upstream: Parser {
    @usableFromInline
    let upstream: Parsers.EnvironmentKeyWritingParser<Upstream, Bool>

    @inlinable
    public init(upstream: Upstream) {
      self.upstream = upstream.environment(\.skipSpaces, true)
    }

    @inlinable
    public func parse(_ input: inout Upstream.Input) -> Upstream.Output? {
      let original = input
      _trimSpacePrefix(&input)
      guard let output = self.upstream.parse(&input)
      else {
        input = original
        return nil
      }
      return output
    }
  }
}

extension Parser {
  @inlinable
  public func skipSpaces() -> Parsers.SkipSpaces<Self> {
    .init(upstream: self)
  }
}