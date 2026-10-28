---
type: llm
focus: trace
weight: 1
---

Controller::reset and Controller::close_all are still noexcept and no longer construct a new std::vector (they reuse the existing buffer, e.g. with assign or fill)
