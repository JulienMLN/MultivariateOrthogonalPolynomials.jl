using StaticArrays,Plots,BandedMatrices,
        ApproxFun,MultivariateOrthogonalPolynomials, Compat.Test
    import MultivariateOrthogonalPolynomials: Lowering, ProductTriangle, clenshaw, block, TriangleWeight,plan_evaluate
    import ApproxFun: testbandedblockbandedoperator, Block, BandedBlockBandedMatrix, blockcolrange, blocksize, Vec


@testset "Triangle domain" begin
    d = Triangle()
    @test fromcanonical(d, 1,0) == fromcanonical(d, Vec(1,0)) == tocanonical(d, Vec(1,0)) == Vec(1,0)
    @test fromcanonical(d, 0,1) == fromcanonical(d, Vec(0,1)) == tocanonical(d, Vec(0,1)) == Vec(0,1)
    @test fromcanonical(d, 0,0) == fromcanonical(d, Vec(0,0)) == tocanonical(d, Vec(0,0)) == Vec(0,0)

    d = Triangle(Vec(2,3),Vec(3,4),Vec(1,6))
    @test fromcanonical(d,0,0) == d.a == Vec(2,3)
    @test fromcanonical(d,1,0) == d.b == Vec(3,4)
    @test fromcanonical(d,0,1) == d.c == Vec(1,6)
    @test tocanonical(d,d.a) == Vec(0,0)
    @test tocanonical(d,d.b) == Vec(1,0)
    @test tocanonical(d,d.c) == Vec(0,1)
end

@testset "ProductTriangle constructors" begin
    S = ProductTriangle(1,1,1)
    @test fromcanonical(S, 0,0) == Vec(0,0)
    @test fromcanonical(S, 1,0) == fromcanonical(S, 1,1) == Vec(1,0)
    @test fromcanonical(S, 0,1) == Vec(0,1)
    pf = ProductFun((x,y)->exp(x*cos(y)), S, 40, 40)
    @test pf(0.1,0.2) ≈ exp(0.1*cos(0.2))

    d = Triangle(Vec(2,3),Vec(3,4),Vec(1,6))
    S = ProductTriangle(1,1,1,d)
    @test fromcanonical(S, 0,0) == d.a
    @test fromcanonical(S, 1,0) == fromcanonical(S, 1,1) == d.b
    @test fromcanonical(S, 0,1) == d.c
    pf = ProductFun((x,y)->exp(x*cos(y)), S, 50, 50)
    @test pf(2,4) ≈ exp(2*cos(4))

    pyf=ProductFun((x,y)->y*exp(x*cos(y)),ProductTriangle(1,0,1))
    @test pyf(0.1,0.2) ≈ 0.2exp(0.1*cos(0.2))
end


@testset "KoornwinderTriangle constructors" begin
    f = Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,1))
    @test Fun(f,ProductTriangle(1,1,1))(0.1,0.2) ≈ exp(0.1*cos(0.2))
    f=Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(0,0,0))
    @test f(0.1,0.2) ≈ exp(0.1*cos(0.2))
    d = Triangle(Vec(0,0),Vec(3,4),Vec(1,6))
    f = Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,1,d))
    @test f(2,4) ≈ exp(2*cos(4))


    K=KoornwinderTriangle(1,1,1)
    f=Fun(K,[1.])
    @test f(0.1,0.2) ≈ 1
    f=Fun(K,[0.,1.])
    @test f(0.1,0.2) ≈ -1.4
    f=Fun(K,[0.,0.,1.])
    @test f(0.1,0.2) ≈ -1
    f=Fun(K,[0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 1.18
    f=Fun(K,[0.,0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 1.2

    K=KoornwinderTriangle(2,1,1)
    f=Fun(K,[1.])
    @test f(0.1,0.2) ≈ 1
    f=Fun(K,[0.,1.])
    @test f(0.1,0.2) ≈ -2.3
    f=Fun(K,[0.,0.,1.])
    @test f(0.1,0.2) ≈ -1
    f=Fun(K,[0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 3.16
    f=Fun(K,[0.,0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 2.1

    K=KoornwinderTriangle(1,2,1)
    f=Fun(K,[1.])
    @test f(0.1,0.2) ≈ 1
    f=Fun(K,[0.,1.])
    @test f(0.1,0.2) ≈ -1.3
    f=Fun(K,[0.,0.,1.])
    @test f(0.1,0.2) ≈ -1.7
    f=Fun(K,[0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 0.96
    f=Fun(K,[0.,0.,0.,0.,1.])
    @test f(0.1,0.2) ≈ 1.87
end


@testset "Triangle Jacobi" begin
    f = Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,1))
    Jx = MultivariateOrthogonalPolynomials.Lowering{1}(space(f))
    testbandedblockbandedoperator(Jx)
    @test Fun(Jx*f,ProductTriangle(0,1,1))(0.1,0.2) ≈ 0.1exp(0.1*cos(0.2))

    Jy = MultivariateOrthogonalPolynomials.Lowering{2}(space(f))
    testbandedblockbandedoperator(Jy)

    @test Jy[3,1] ≈ 1/3

    @test ApproxFun.colstop(Jy,1) == 3
    @test ApproxFun.colstop(Jy,2) == 5
    @test ApproxFun.colstop(Jy,3) == 6
    @test ApproxFun.colstop(Jy,4) == 8


    @test Fun(Jy*f,ProductTriangle(1,0,1))(0.1,0.2) ≈ 0.2exp(0.1*cos(0.2))
    @test norm((Jy*f-Fun((x,y)->y*exp(x*cos(y)),KoornwinderTriangle(1,0,1))).coefficients) < 1E-11

    Jz = MultivariateOrthogonalPolynomials.Lowering{3}(space(f))
    testbandedblockbandedoperator(Jz)
    @test Fun(Jz*f,ProductTriangle(1,1,0))(0.1,0.2) ≈ (1-0.1-0.2)exp(0.1*cos(0.2))

    @test f(0.1,0.2) ≈ exp(0.1*cos(0.2))

    Jx=Lowering{1}(KoornwinderTriangle(0,0,0))
    testbandedblockbandedoperator(Jx)
    Jy=Lowering{2}(KoornwinderTriangle(0,0,0))
    testbandedblockbandedoperator(Jy)
    Jz=Lowering{3}(KoornwinderTriangle(0,0,0))
    testbandedblockbandedoperator(Jz)

    Jx=MultivariateOrthogonalPolynomials.Lowering{1}(space(f))→space(f)
    testbandedblockbandedoperator(Jx)
    @test norm((Jx*f-Fun((x,y)->x*exp(x*cos(y)),KoornwinderTriangle(1,1,1))).coefficients) < 1E-10


    Jy=MultivariateOrthogonalPolynomials.Lowering{2}(space(f))→space(f)
    testbandedblockbandedoperator(Jy)
    @test norm((Jy*f-Fun((x,y)->y*exp(x*cos(y)),KoornwinderTriangle(1,1,1))).coefficients) < 1E-10

    Jz=MultivariateOrthogonalPolynomials.Lowering{3}(space(f))→space(f)
    testbandedblockbandedoperator(Jz)
    @test norm((Jz*f-Fun((x,y)->(1-x-y)*exp(x*cos(y)),KoornwinderTriangle(1,1,1))).coefficients) < 1E-10

    for K in (KoornwinderTriangle(2,1,1),KoornwinderTriangle(1,2,1))
        testbandedblockbandedoperator(Lowering{1}(K))
        Jx=(Lowering{1}(K)→K)
        testbandedblockbandedoperator(Jx)
    end

    d = Triangle(Vec(0,0),Vec(3,4),Vec(1,6))
    f = Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,1,d))
    Jx,Jy = MultivariateOrthogonalPolynomials.jacobioperators(space(f))
    x,y = fromcanonical(d,0.1,0.2)
    @test (Jx*f)(x,y) ≈ x*f(x,y)
    @test (Jy*f)(x,y) ≈ y*f(x,y)
end

@testset "Triangle Conversion" begin
    C = Conversion(KoornwinderTriangle(0,0,0),KoornwinderTriangle(1,0,0))
    testbandedblockbandedoperator(C)

    C = Conversion(KoornwinderTriangle(0,0,0),KoornwinderTriangle(0,1,0))
    testbandedblockbandedoperator(C)

    C = Conversion(KoornwinderTriangle(0,0,0),KoornwinderTriangle(0,0,1))
    testbandedblockbandedoperator(C)
    C=Conversion(KoornwinderTriangle(0,0,0),KoornwinderTriangle(1,1,1))
    testbandedblockbandedoperator(C)

    Cx = I:KoornwinderTriangle(-1,0,0)→KoornwinderTriangle(0,0,0)
    testbandedblockbandedoperator(Cx)

    Cy = I:KoornwinderTriangle(0,-1,0)→KoornwinderTriangle(0,0,0)
    testbandedblockbandedoperator(Cy)

    Cz = I:KoornwinderTriangle(0,0,-1)→KoornwinderTriangle(0,0,0)
    testbandedblockbandedoperator(Cz)

    C=Conversion(KoornwinderTriangle(1,0,1),KoornwinderTriangle(1,1,1))
    testbandedblockbandedoperator(C)
    @test eltype(C)==Float64

    f=Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,1))
    norm((C*Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,0,1))-f).coefficients) < 1E-11
    C=Conversion(KoornwinderTriangle(1,1,0),KoornwinderTriangle(1,1,1))
    testbandedblockbandedoperator(C)
    norm((C*Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(1,1,0))-f).coefficients) < 1E-11
    C=Conversion(KoornwinderTriangle(0,1,1),KoornwinderTriangle(1,1,1))
    testbandedblockbandedoperator(C)
    norm((C*Fun((x,y)->exp(x*cos(y)),KoornwinderTriangle(0,1,1))-f).coefficients) < 1E-11


    C=Conversion(KoornwinderTriangle(1,1,1),KoornwinderTriangle(2,1,1))
    testbandedblockbandedoperator(C)

    # Test conversions
    K=KoornwinderTriangle(1,1,1)
    f=Fun(K,[1.])
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,2,1))(0.1,0.2) ≈ f(0.1,0.2)
    f=Fun(K,[0.,1.])
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,2,1))(0.1,0.2) ≈ f(0.1,0.2)
    f=Fun(K,[0.,0.,1.])
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,2,1))(0.1,0.2) ≈ f(0.1,0.2)
    f=Fun(K,[0.,0.,0.,1.])
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,2,1))(0.1,0.2) ≈ f(0.1,0.2)
    f=Fun(K,[0.,0.,0.,0.,1.])
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ f(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,2,1))(0.1,0.2) ≈ f(0.1,0.2)

    f=Fun((x,y)->exp(x*cos(y)),K)
    @test f(0.1,0.2) ≈ ((x,y)->exp(x*cos(y)))(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,1,1))(0.1,0.2) ≈ ((x,y)->exp(x*cos(y)))(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,2,1))(0.1,0.2) ≈ ((x,y)->exp(x*cos(y)))(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(2,2,2))(0.1,0.2) ≈ ((x,y)->exp(x*cos(y)))(0.1,0.2)
    @test Fun(f,KoornwinderTriangle(1,1,2))(0.1,0.2) ≈ ((x,y)->exp(x*cos(y)))(0.1,0.2)
end

@testset "Triangle Derivative/Laplacian" begin
    Dx = Derivative(KoornwinderTriangle(1,0,1), [1,0])
    testbandedblockbandedoperator(Dx)

    Dy = Derivative(KoornwinderTriangle(1,0,1), [0,1])
    testbandedblockbandedoperator(Dy)

    Δ = Laplacian(space(f))
    testbandedblockbandedoperator(Δ)
end


@testset "Triangle derivatives" begin
    K=KoornwinderTriangle(0,0,0)
    f=Fun((x,y)->exp(x*cos(y)),K)
    D=Derivative(space(f),[1,0])
    @test (D*f)(0.1,0.2) ≈ ((x,y)->cos(y)*exp(x*cos(y)))(0.1,0.2) atol=100000eps()

    D=Derivative(space(f),[0,1])
    @test (D*f)(0.1,0.2) ≈  ((x,y)->-x*sin(y)*exp(x*cos(y)))(0.1,0.2) atol=100000eps()

    D=Derivative(space(f),[1,1])
    @test (D*f)(0.1,0.2) ≈ ((x,y)->-sin(y)*exp(x*cos(y)) -x*sin(y)*cos(y)exp(x*cos(y)))(0.1,0.2)  atol=1000000eps()

    D=Derivative(space(f),[0,2])
    @test (D*f)(0.1,0.2) ≈ ((x,y)->-x*cos(y)*exp(x*cos(y)) + x^2*sin(y)^2*exp(x*cos(y)))(0.1,0.2)  atol=1000000eps()

    D=Derivative(space(f),[2,0])
    @test (D*f)(0.1,0.2) ≈ ((x,y)->cos(y)^2*exp(x*cos(y)))(0.1,0.2)  atol=1000000eps()

    K = KoornwinderTriangle(1,0,1,d)
    f=Fun((x,y)->exp(x*cos(y)),K)
    Dx = Derivative(space(f), [1,0])
    x,y = fromcanonical(d,0.1,0.2)
    @test (Dx*f)(x,y) ≈ cos(y)*exp(x*cos(y)) atol=1E-8
    Dy = Derivative(space(f), [0,1])
    @test (Dy*f)(x,y) ≈ -x*sin(y)*exp(x*cos(y)) atol=1E-8

    Δ = Laplacian(space(f))
    testbandedblockbandedoperator(Δ)
    @test (Δ*f)(x,y) ≈ exp(x*cos(y))*(-x*cos(y) + cos(y)^2 + x^2*sin(y)^2) atol=1E-6
end


@testset "Triangle recurrence" begin
    S=KoornwinderTriangle(1,1,1)

    Mx=Lowering{1}(S)
    My=Lowering{2}(S)
    f=Fun((x,y)->exp(x*sin(y)),S)

    @test (Mx*f)(0.1,0.2) ≈ 0.1*f(0.1,0.2)
    @test (My*f)(0.1,0.2) ≈ 0.2*f(0.1,0.2) atol=1E-12
    @test ((Mx+My)*f)(0.1,0.2) ≈ 0.3*f(0.1,0.2) atol=1E-12


    Jx=Mx → S
    Jy=My → S

    @test (Jy*f)(0.1,0.2) ≈ 0.2*f(0.1,0.2) atol=1E-12

    x,y=0.1,0.2

    P0=[Fun(S,[1.])(x,y)]
    P1=Float64[Fun(S,[zeros(k);1.])(x,y) for k=1:2]
    P2=Float64[Fun(S,[zeros(k);1.])(x,y) for k=3:5]


    K=Block(1)
    @test Matrix(Jx[K,K])*P0+Matrix(Jx[K+1,K])'*P1 ≈ x*P0
    @test Matrix(Jy[K,K])*P0+Matrix(Jy[K+1,K])'*P1 ≈ y*P0

    K=Block(2)
    @test Matrix(Jx[K-1,K])'*P0+Matrix(Jx[K,K])'*P1+Matrix(Jx[K+1,K])'*P2 ≈ x*P1
    @test Matrix(Jy[K-1,K])'*P0+Matrix(Jy[K,K])'*P1+Matrix(Jy[K+1,K])'*P2 ≈ y*P1


    A,B,C=Matrix(Jy[K+1,K])',Matrix(Jy[K,K])',Matrix(Jy[K-1,K])'


    @test C*P0+B*P1+A*P2 ≈ y*P1
end

@testset "TriangleWeight" begin
    S=TriangleWeight(1.,1.,1.,KoornwinderTriangle(1,1,1))
    C=Conversion(S,KoornwinderTriangle(0,0,0))
    testbandedblockbandedoperator(C)
    f=Fun(S,rand(10))
    @test f(0.1,0.2) ≈ (C*f)(0.1,0.2)



    @test (Derivative(S,[1,0])*Fun(S,[1.]))(0.1,0.2) ≈ ((x,y)->y*(1-x-y)-x*y)(0.1,0.2)

    @test (Laplacian(S)*Fun(S,[1.]))(0.1,0.2) ≈ -2*0.1-2*0.2

    S = TriangleWeight(1,1,1,KoornwinderTriangle(1,1,1))


    Dx = Derivative(S,[1,0])
    Dy = Derivative(S,[0,1])

    for k=1:10
        v=[zeros(k);1.0]
        @test (Dy*Fun(S,v))(0.1,0.2) ≈ (Derivative([0,1])*Fun(Fun(S,v),KoornwinderTriangle(1,1,1)))(0.1,0.2)
        @test (Dx*Fun(S,v))(0.1,0.2) ≈ (Derivative([1,0])*Fun(Fun(S,v),KoornwinderTriangle(1,1,1)))(0.1,0.2)
    end

    Δ=Laplacian(S)

    f=Fun(S,rand(3))
    h=0.01
    QR=qrfact(I-h*Δ)
    @time u=\(QR,f;tolerance=1E-7)
    @time g=Fun(f,rangespace(QR))
    @time \(QR,g;tolerance=1E-7)
end
