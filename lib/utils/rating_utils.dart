import 'dart:math' as math;

/// Rating utilities implementing AtCoder-like supplemental formulas.
///
/// Formulas (from user's spec):
/// mapRating(r) = r                       if r > 400
///              = 400 / exp((400 - r)/400) if r <= 400
///
/// F(n) = sqrt(sum_{i=1..n} 0.81^i) / (sum_{i=1..n} 0.9^i)
/// f(n) = (F(n) - F(infty)) / (F(1) - F(infty)) * 1200
///
/// TrueRating = mapRating(Rating - f(n))
class RatingUtils {
  RatingUtils._();

  /// Maps ratings (or difficulties) below or equal to 400
  /// to a positive scale per the provided exponential mapping.
  /// Returns a double to keep precision; callers can round if needed.
  static double mapRating(num r) {
    final rr = r.toDouble();
    if (rr > 400.0) return rr;
    return 400.0 / math.exp((400.0 - rr) / 400.0);
  }

  /// Computes F(n) using closed-form geometric sums.
  /// sum_{i=1..n} a^i = a * (1 - a^n) / (1 - a)
  static double _F(int n) {
    if (n <= 0) return 0.0;
    const a1 = 0.81; // 0.9^2
    const a2 = 0.9;
    final sum1 = a1 * (1 - math.pow(a1, n)) / (1 - a1);
    final sum2 = a2 * (1 - math.pow(a2, n)) / (1 - a2);
    return math.sqrt(sum1) / sum2;
  }

  /// F(infty) using closed-form limits of geometric sums.
  static double _FInf() {
    const a1 = 0.81;
    const a2 = 0.9;
    final sum1Inf = a1 / (1 - a1);
    final sum2Inf = a2 / (1 - a2);
    return math.sqrt(sum1Inf) / sum2Inf;
  }

  /// f(n) per the provided formula.
  static double f(int n) {
    if (n <= 0) return 1200.0; // safe fallback; not expected in practice
    final fn = _F(n);
    final finf = _FInf();
    final f1 = _F(1);
    // Avoid division by a tiny number; clamp if needed
    final denom = (f1 - finf).abs() < 1e-12 ? 1e-12 : (f1 - finf);
    return ((fn - finf) / denom) * 1200.0;
  }

  /// Computes TrueRating = mapRating(Rating - f(n)).
  static double trueRating({required num rating, required int contests}) {
    return mapRating(rating - f(contests));
  }
}
