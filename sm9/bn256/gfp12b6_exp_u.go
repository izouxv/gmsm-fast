package bn256

// Use special square
func (e *gfP12b6) gfP12ExpU(x *gfP12b6) *gfP12b6 {
	// The sequence of 10 multiplications and 61 squarings is derived from the
	// following addition chain generated with github.com/mmcloughlin/addchain v0.4.0.
	//
	//	_10    = 2*1
	//	_100   = 2*_10
	//	_101   = 1 + _100
	//	_1001  = _100 + _101
	//	_1011  = _10 + _1001
	//	_1100  = 1 + _1011
	//	i56    = (_1100 << 40 + _1011) << 7 + _1011 + _100
	//	i69    = (2*(i56 << 4 + _1001) + 1) << 6
	//	return   2*(_101 + i69)
	//
	var z = e
	var t0 = new(gfP12b6)
	var t1 = new(gfP12b6)
	var t2 = new(gfP12b6)
	var t3 = new(gfP12b6)

	t2.SpecialSquareNC(x)
	t1.SpecialSquareNC(t2)
	z.MulNC(x, t1)
	t0.MulNC(t1, z)
	t2.Mul(t2, t0)
	t3.MulNC(x, t2)
	t3.SpecialSquares(t3, 40)
	t3.Mul(t2, t3)
	t3.SpecialSquares(t3, 7)
	t2.Mul(t2, t3)
	t1.Mul(t1, t2)
	t1.SpecialSquares(t1, 4)
	t0.Mul(t0, t1)
	t0.SpecialSquare(t0)
	t0.Mul(x, t0)
	t0.SpecialSquares(t0, 6)
	z.Mul(z, t0)
	z.SpecialSquare(z)
	return e
}
