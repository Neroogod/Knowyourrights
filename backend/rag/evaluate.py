"""Deterministic trust-gate evaluation for Nigerian legal RAG."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from backend.content_store import ContentStore

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATASET = ROOT / "evaluations" / "nigerian_legal_gold.json"
DEFAULT_BASELINE = ROOT / "evaluations" / "baseline.json"


def evaluate(dataset_path: Path = DEFAULT_DATASET) -> dict:
    # CI measures retrieval/grounding deterministically and never spends model tokens.
    os.environ.pop("OPENAI_API_KEY", None)
    store = ContentStore.from_file()
    answerers = {
        "rights": store.ask,
        "company": store.ask_company,
        "students": store.ask_students,
    }
    cases = json.loads(dataset_path.read_text(encoding="utf-8"))
    results: list[dict] = []
    for case in cases:
        response = answerers[case["corpus"]](case["question"])
        actual_locators = {citation.locator for citation in response.citations}
        expected = set(case.get("gold_locators", []))
        citation_ok = response.refused or bool(actual_locators & expected)
        terms = case.get("answer_terms", [])
        answer_ok = response.refused or all(term.lower() in response.answer.lower() for term in terms)
        refusal_ok = response.refused is bool(case["must_refuse"])
        results.append(
            {
                "id": case["id"],
                "refusal_ok": refusal_ok,
                "citation_ok": citation_ok,
                "answer_ok": answer_ok,
                "refused": response.refused,
                "actual_locators": sorted(actual_locators),
            }
        )

    answered = [item for item in results if not item["refused"]]
    metrics = {
        "case_count": len(results),
        "refusal_accuracy": sum(item["refusal_ok"] for item in results) / len(results),
        "gold_citation_accuracy": (
            sum(item["citation_ok"] for item in answered) / len(answered) if answered else 0.0
        ),
        "answer_term_accuracy": (
            sum(item["answer_ok"] for item in answered) / len(answered) if answered else 0.0
        ),
    }
    return {"metrics": metrics, "results": results}


def passes_gate(report: dict, baseline_path: Path = DEFAULT_BASELINE) -> tuple[bool, list[str]]:
    metrics = report["metrics"]
    minimums = {
        "refusal_accuracy": 0.9,
        "gold_citation_accuracy": 0.9,
        "answer_term_accuracy": 0.8,
    }
    failures = [
        f"{name}={metrics[name]:.3f} is below {minimum:.3f}"
        for name, minimum in minimums.items()
        if metrics[name] < minimum
    ]
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))["metrics"]
        for name in minimums:
            if metrics[name] + 0.01 < baseline[name]:
                failures.append(f"{name} regressed from {baseline[name]:.3f} to {metrics[name]:.3f}")
    return not failures, failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--write-report", type=Path)
    args = parser.parse_args()
    report = evaluate(args.dataset)
    print(json.dumps(report, indent=2))
    if args.write_report:
        args.write_report.write_text(json.dumps(report, indent=2) + "\n")
    passed, failures = passes_gate(report, args.baseline)
    for failure in failures:
        print(f"AI TRUST GATE: {failure}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
