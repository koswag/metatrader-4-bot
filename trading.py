
class Bar:
    def __init__(self, openVal, closeVal, high, low):
        self.openVal = openVal
        self.closeVal = closeVal
        self.high = high
        self.low = low

        if closeVal > openVal:
            self.isUp = True
        else:
            self.isUp = False


class Strategy:
    def __init__(self, interval, min_bars=5, max_bars=20, up_err=0.0007, bott_err=0.0005):
        self.interval = interval
        self.min_bars = min_bars
        self.max_bars = max_bars
        self.up_err = up_err
        self.bott_err = bott_err
        self.bars = []
        self.counter = 0

    def add_bar(self, open, close, high, low):
        self.bars.append(
            Bar(open, close, high, low)
        )

        if len(self.bars) == self.min_bars:
            highs = []
            lows = []
            for bar in self.bars:
                highs.append(bar.high)
                lows.append(bar.low)
            self.roof = get_high(highs)
            self.floor = get_low(lows)


def get_high(highs):
    f_max, s_max = max_vals(highs)
    diff = f_max - s_max
    if diff/s_max > 1: # ?
        return s_max
    else:
        return f_max


def max_vals(arr):
    if len(arr) == 0:
        return None
    if len(arr) == 1:
        return arr[0]
    f_max = max(arr[0], arr[1])
    s_max = min(arr[0], arr[1])
    
    for x in arr:
        if x > f_max:
            f_max = x
        elif x > s_max:
            s_max = x
    return f_max, s_max


def get_low(lows):
    f_min, s_min = min_vals(lows)
    diff = s_min - f_min
    if diff/s_min > 1: # ?
        return s_min
    else:
        return f_min


def min_vals(arr):
    if len(arr) == 0:
        return None
    if len(arr) == 1:
        return arr[0]
    f_min = min(arr[0], arr[1])
    s_min = max(arr[0], arr[1])

    for x in arr:
        if x < f_min:
            f_min = x
        elif x < s_min:
            s_min = x
    return f_min, s_min
