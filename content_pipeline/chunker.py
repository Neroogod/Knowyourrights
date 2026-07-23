"""Split text into overlapping, token-bounded chunks for retrieval."""

import re

WORD = re.compile(r"\S+")


def tokenize(text: str) -> list[str]:
    """Whitespace tokenisation (word-ish units) used for chunk sizing."""
    return WORD.findall(text)


def chunk_text(text: str, max_tokens: int = 180, overlap: int = 30) -> list[str]:
    """Break text into chunks of up to max_tokens words with a fixed word overlap.

    Overlap preserves context across chunk boundaries so a citation-bearing
    sentence is not split away from its surrounding meaning.
    """
    if max_tokens <= 0:
        raise ValueError("max_tokens must be positive")
    if overlap < 0:
        raise ValueError("overlap must be >= 0")

    tokens = tokenize(text)
    if not tokens:
        return []

    effective_overlap = min(overlap, max_tokens - 1)
    chunks: list[str] = []
    step = max_tokens - effective_overlap
    for start in range(0, len(tokens), step):
        window = tokens[start : start + max_tokens]
        if window:
            chunks.append(" ".join(window))
        if start + max_tokens >= len(tokens):
            break
    return chunks


if __name__ == "__main__":

    def test_tokenize() -> None:
        assert tokenize("one two   three") == ["one", "two", "three"]
        print("test_tokenize passed")

    def test_empty_text_returns_no_chunks() -> None:
        assert chunk_text("") == []
        print("test_empty_text_returns_no_chunks passed")

    def test_short_text_single_chunk() -> None:
        assert chunk_text("a b c", max_tokens=10) == ["a b c"]
        print("test_short_text_single_chunk passed")

    def test_chunking_respects_max_tokens() -> None:
        text = " ".join(str(i) for i in range(100))
        chunks = chunk_text(text, max_tokens=40, overlap=10)
        assert all(len(tokenize(c)) <= 40 for c in chunks)
        assert len(chunks) >= 3
        print("test_chunking_respects_max_tokens passed")

    def test_overlap_preserves_context() -> None:
        text = " ".join(str(i) for i in range(50))
        chunks = chunk_text(text, max_tokens=20, overlap=5)
        first_tail = chunks[0].split()[-5:]
        second_head = chunks[1].split()[:5]
        assert first_tail == second_head
        print("test_overlap_preserves_context passed")

    def test_invalid_params_raise() -> None:
        for bad in (lambda: chunk_text("x", max_tokens=0), lambda: chunk_text("x", max_tokens=5, overlap=-1)):
            try:
                bad()
                raise AssertionError("expected ValueError")
            except ValueError:
                pass
        print("test_invalid_params_raise passed")

    def test_overlap_clamped_for_small_max_tokens() -> None:
        assert chunk_text("a b c", max_tokens=10) == ["a b c"]
        print("test_overlap_clamped_for_small_max_tokens passed")

    test_tokenize()
    test_empty_text_returns_no_chunks()
    test_short_text_single_chunk()
    test_chunking_respects_max_tokens()
    test_overlap_preserves_context()
    test_invalid_params_raise()
    test_overlap_clamped_for_small_max_tokens()
    print("\nAll tests passed!")
