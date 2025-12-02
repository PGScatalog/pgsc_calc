class ScoreUtils {
    static def roundList(ArrayList l, int decimals = 6) {
        l.collect { row ->
            row.collect { item ->
                try {
                    // try to parse as a number
                    def num = new BigDecimal(item)
                    num.setScale(decimals, BigDecimal.ROUND_HALF_UP)
                } catch (NumberFormatException e) {
                    // not a number, return original string
                    item
                }
            }
        }
    }
}