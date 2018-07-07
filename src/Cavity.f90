!--------------------------------------------------
!>Specify the KIND value
!--------------------------------------------------
module NumberKinds
    implicit none

    integer, parameter                                  :: KREAL = kind(0.d0)
    integer, parameter                                  :: KINT = kind(1)
end module NumberKinds

!--------------------------------------------------
!>Define the global constant variables
!--------------------------------------------------
module ConstantVariables
    use NumberKinds
    implicit none

    real(KREAL), parameter                              :: PI = 4.0*atan(1.0) !Pi
    real(KREAL), parameter                              :: SMV = tiny(0.0) !Small value to avoid 0/0
    real(KREAL), parameter                              :: UP = 1.0 !Used in sign() function

    !Direction
    integer(KINT), parameter                            :: IDIRC = 1 !I direction
    integer(KINT), parameter                            :: JDIRC = 2 !J direction
end module ConstantVariables

!--------------------------------------------------
!>Define the mesh data structure
!--------------------------------------------------
module Mesh
    use NumberKinds
    implicit none

    !--------------------------------------------------
    !Basic derived type
    !--------------------------------------------------
    !Cell center
    type CellCenter
        !Geometry
        real(KREAL)                                     :: x,y !Cell center coordinates
        real(KREAL)                                     :: area !Cell area
        real(KREAL)                                     :: length(2) !Cell length in i and j direction
        !Flow field
        real(KREAL)                                     :: conVars(4) !Conservative variables at cell center: density, x-momentum, y-momentum, total energy
        real(KREAL), allocatable, dimension(:,:)        :: h,b !Distribution function
        real(KREAL), allocatable, dimension(:,:,:)      :: sh,sb !Slope of distribution function in i and j direction
    end type CellCenter

    !Cell interface
    type CellInterface
        !geometry
        real(KREAL)                                     :: length !Length of cell interface
        real(KREAL)                                     :: cosx,cosy !Directional cosine in global frame
        !Flux
        real(KREAL)                                     :: flux(4) !Conservative variables flux at cell interface: density flux, x and y momentum flux, total energy flux
        real(KREAL), allocatable, dimension(:,:)        :: flux_h,flux_b !Flux of distribution function
    end type CellInterface

    !index method
    !          (i,j+1)
    !     ----------------
    !     |              |
    !     |              |
    !     |              |
    !(i,j)|     (i,j)    |(i+1,j)
    !     |      Cell    |
    !     |              |
    !     |              |
    !     ----------------
    !           (i,j)
end module Mesh

module ControlParameters
    use ConstantVariables
    use Mesh
    implicit none

    !--------------------------------------------------
    !Variables to control the simulation
    !--------------------------------------------------
    real(KREAL), parameter                              :: CFL = 0.8 !CFL number
    ! real(KREAL), parameter                              :: MAX_TIME = 250.0 !Maximal simulation time
    integer(KINT), parameter                            :: MAX_ITER = 5E5 !Maximal iteration number
    real(KREAL), parameter                              :: EPS = 1.0E-5 !Convergence criteria
    real(KREAL)                                         :: simTime = 0.0 !Current simulation time
    integer(KINT)                                       :: iter = 1 !Number of iteration
    real(KREAL)                                         :: dt !Global time step
    real(KREAL)                                         :: res(4) !Residual
    
    !Output control
    character(len=6), parameter                         :: HSTFILENAME = "Cavity" !History file name
    character(len=6), parameter                         :: RSTFILENAME = "Cavity" !Result file name
    integer(KINT), parameter                            :: HSTFILE = 20 !History file ID
    integer(KINT), parameter                            :: RSTFILE = 21 !Result file ID

    !Gas propeties
    integer(KINT), parameter                            :: CK = 1 !Internal degree of freedom, here 1 denotes monatomic gas
    real(KREAL), parameter                              :: GAMMA = real(CK+4,KREAL)/real(CK+2,KREAL) !Ratio of specific heat
    real(KREAL), parameter                              :: OMEGA = 0.81 !Temperature dependence index in HS/VHS/VSS model
    real(KREAL), parameter                              :: PR = 2.0/3.0 !Prandtl number
    real(KREAL), parameter                              :: KN = 0.075 !Knudsen number in reference state
    real(KREAL), parameter                              :: ALPHA_REF = 1.0 !Coefficient in HS model
    real(KREAL), parameter                              :: OMEGA_REF = 0.5 !Coefficient in HS model
    real(KREAL), parameter                              :: MU_REF = 5.0*(ALPHA_REF+1.0)*(ALPHA_REF+2.0)*sqrt(PI)/(4.0*ALPHA_REF*(5.0-2.0*OMEGA_REF)*(7.0-2.0*OMEGA_REF))*KN !Viscosity coefficient in reference state

    !Geometry
    real(KREAL), parameter                              :: X_START = 0.0, X_END = 1.0, Y_START = 0.0, Y_END = 1.0 !Start point and end point in x, y direction 
    integer(KINT), parameter                            :: X_NUM = 45, Y_NUM = 45 !Points number in x, y direction
    integer(KINT), parameter                            :: IXMIN = 1 , IXMAX = X_NUM, IYMIN = 1 , IYMAX = Y_NUM !Cell index range
    integer(KINT), parameter                            :: N_GRID = (IXMAX-IXMIN+1)*(IYMAX-IYMIN+1) !Total number of cell
    integer(KINT), parameter                            :: GHOST_NUM = 1 !Ghost cell number

    !--------------------------------------------------
    !Initial flow field
    !--------------------------------------------------
    !Index method
    !-------------------------------
    !| (i-1) |  (i) |  (i) | (i+1) |
    !| cell  | face | cell | face  |
    !-------------------------------
    ! type(CellCenter)                                    :: ctr(IXMIN-GHOST_NUM:IXMAX+GHOST_NUM) !Cell center (with ghost cell)
    ! type(CellInterface)                                 :: vface(IXMIN-GHOST_NUM+1:IXMAX+GHOST_NUM),hface !Vertical and horizontal interfaces

    !Initial condition (density, u-velocity, v-velocity, lambda=1/temperature)
    real(KREAL), parameter, dimension(4)                :: INIT_GAS = [1.0, 0.0, 0.0, 1.0]

    !Boundary condition (density, u-velocity, v-velocity, lambda=1/temperature)
    real(KREAL), parameter, dimension(4)                :: BC_W = [1.0, 0.0, 0.0, 1.0] !West boundary
    real(KREAL), parameter, dimension(4)                :: BC_E = [1.0, 0.0, 0.0, 1.0] !East boundary
    real(KREAL), parameter, dimension(4)                :: BC_S = [1.0, 0.0, 0.0, 1.0] !South boundary
    real(KREAL), parameter, dimension(4)                :: BC_N = [1.0, 0.15, 0.0, 1.0] !North boundary

    !--------------------------------------------------
    !Discrete velocity space
    !--------------------------------------------------
    integer(KINT)                                       :: uNum = 64, vNum = 64 !Number of points in velocity space for u and v
    real(KREAL), parameter                              :: U_MIN = -15.0, U_MAX = +15.0, V_MIN = -15.0, V_MAX = +15.0 !Minimum and maximum micro velocity
    real(KREAL), allocatable, dimension(:,:)            :: uSpace,vSpace !Discrete velocity space for u and v
    real(KREAL), allocatable, dimension(:,:)            :: weight !Qudrature weight for discrete points in velocity space

end module ControlParameters

!--------------------------------------------------
!>Define some commonly used functions/subroutines
!--------------------------------------------------
module Tools
    use ControlParameters
    implicit none

contains
    !--------------------------------------------------
    !>Convert macro variables from global frame to local
    !>@param[in] w            :macro variables in global frame
    !>@param[in] cosx,cosy    :directional cosine
    !>@return    LocalFrame   :macro variables in local frame
    !--------------------------------------------------
    function LocalFrame(w,cosx,cosy)
        real(KREAL), intent(in)                         :: w(4)
        real(KREAL), intent(in)                         :: cosx,cosy
        real(KREAL)                                     :: LocalFrame(4)

        LocalFrame(1) = w(1)
        LocalFrame(2) = w(2)*cosx+w(3)*cosy
        LocalFrame(3) = -w(2)*cosy+w(3)*cosx
        LocalFrame(4) = w(4)
    end function LocalFrame

    !--------------------------------------------------
    !>Convert macro variables from local frame to global
    !>@param[in] w            :macro variables in local frame
    !>@param[in] cosx,cosy    :directional cosine
    !>@return    GlobalFrame  :macro variables in global frame
    !--------------------------------------------------
    function GlobalFrame(w,cosx,cosy)
        real(KREAL) , intent(in)                        :: w(4)
        real(KREAL) , intent(in)                        :: cosx,cosy
        real(KREAL)                                     :: GlobalFrame(4)

        GlobalFrame(1) = w(1)
        GlobalFrame(2) = w(2)*cosx-w(3)*cosy
        GlobalFrame(3) = w(2)*cosy+w(3)*cosx
        GlobalFrame(4) = w(4)
    end function GlobalFrame

    !--------------------------------------------------
    !>Convert primary variables to conservative variables
    !>@param[in] prim          :primary variables
    !>@return    GetConserved  :conservative variables
    !--------------------------------------------------
    function GetConserved(prim)
        real(KREAL), intent(in)                         :: prim(4) !Density, x-velocity, y-velocity, lambda=1/temperature
        real(KREAL)                                     :: GetConserved(4) !Density, x-momentum, y-momentum, total energy

        GetConserved(1) = prim(1)
        GetConserved(2) = prim(1)*prim(2)
        GetConserved(3) = prim(1)*prim(3)
        GetConserved(4) = 0.5*prim(1)/(prim(4)*(GAMMA-1.0))+0.5*prim(1)*(prim(2)**2+prim(3)**2)
    end function GetConserved

    !--------------------------------------------------
    !>Convert conservative variables to primary variables
    !>@param[in] w           :conservative variables
    !>@return    GetPrimary  :primary variables
    !--------------------------------------------------
    function GetPrimary(w)
        real(KREAL), intent(in)                         :: w(4) !Density, x-momentum, y-momentum, total energy
        real(KREAL)                                     :: GetPrimary(4) !Density, x-velocity, y-velocity, lambda=1/temperature

        GetPrimary(1) = w(1)
        GetPrimary(2) = w(2)/w(1)
        GetPrimary(3) = w(3)/w(1)
        GetPrimary(4) = 0.5*w(1)/((GAMMA-1.0)*(w(4)-0.5*(w(2)**2+w(3)**2)/w(1)))
    end function GetPrimary

    !--------------------------------------------------
    !>Obtain speed of sound
    !>@param[in] prim    :primary variables
    !>@return    GetSoundSpeed :speed of sound
    !--------------------------------------------------
    function GetSoundSpeed(prim)
        real(KREAL), intent(in)                         :: prim(4)
        real(KREAL)                                     :: GetSoundSpeed !Speed of sound

        GetSoundSpeed = sqrt(0.5*GAMMA/prim(4))
    end function GetSoundSpeed

    !--------------------------------------------------
    !>Obtain discretized Maxwellian distribution
    !>@param[out] h,b   :distribution function
    !>@param[in]  vn,vt :normal and tangential velocity
    !>@param[in]  prim  :primary variables
    !--------------------------------------------------
    subroutine DiscreteMaxwell(h,b,vn,vt,prim)
        real(KREAL), dimension(:,:), intent(out)        :: h,b !Reduced distribution function
        real(KREAL), dimension(:,:), intent(in)         :: vn,vt !Normal and tangential velocity
        real(KREAL), intent(in)                         :: prim(4)

        h = prim(1)*(prim(4)/PI)*exp(-prim(4)*((vn-prim(2))**2+(vt-prim(3))**2))
        b = h*CK/(2.0*prim(4))
    end subroutine DiscreteMaxwell

    !--------------------------------------------------
    !>Calculate the Shakhov part H^+, B^+
    !>@param[in]  H,B           :Maxwellian distribution function
    !>@param[in]  vn,vt         :normal and tangential velocity
    !>@param[in]  qf            :heat flux
    !>@param[in]  prim          :primary variables
    !>@param[out] H_plus,B_plus :Shakhov part
    !--------------------------------------------------
    subroutine ShakhovPart(H,B,vn,vt,qf,prim,H_plus,B_plus)
        real(KREAL), dimension(:,:), intent(in)         :: H,B
        real(KREAL), dimension(:,:), intent(in)         :: vn,vt
        real(KREAL), intent(in)                         :: qf(2)
        real(KREAL), intent(in)                         :: prim(4)
        real(KREAL), dimension(:,:), intent(out)        :: H_plus,B_plus

        H_plus = 0.8*(1-PR)*prim(4)**2/prim(1)*&
                    ((vn-prim(2))*qf(1)+(vt-prim(3))*qf(2))*(2*prim(4)*((vn-prim(2))**2+(vt-prim(3))**2)+CK-5)*H
        B_plus = 0.8*(1-PR)*prim(4)**2/prim(1)*&
                    ((vn-prim(2))*qf(1)+(vt-prim(3))*qf(2))*(2*prim(4)*((vn-prim(2))**2+(vt-prim(3)**2))+CK-3)*B
    end subroutine ShakhovPart
    
    !--------------------------------------------------
    !>VanLeerLimiter for reconstruction of distrubution function
    !>@param[in]    leftCell  :the left cell
    !>@param[inout] midCell   :the middle cell
    !>@param[in]    rightCell :the right cell
    !>@param[in]    idx       :the index indicating i or j direction
    !--------------------------------------------------
    subroutine VanLeerLimiter(leftCell,midCell,rightCell,idx)
        type(CellCenter), intent(in)                    :: leftCell,rightCell
        type(CellCenter), intent(inout)                 :: midCell
        integer(KINT), intent(in)                       :: idx
        real(KREAL), allocatable, dimension(:,:)        :: sL,sR

        !allocate array
        allocate(sL(uNum,vNum))
        allocate(sR(uNum,vNum))

        sL = (midCell%h-leftCell%h)/(0.5*(midCell%length(idx)+leftCell%length(idx)))
        sR = (rightCell%h-midCell%h)/(0.5*(rightCell%length(idx)+midCell%length(idx)))
        midCell%sh(:,:,idx) = (sign(UP,sR)+sign(UP,sL))*abs(sR)*abs(sL)/(abs(sR)+abs(sL)+SMV)

        sL = (midCell%b-leftCell%b)/(0.5*(midCell%length(idx)+leftCell%length(idx)))
        sR = (rightCell%b-midCell%b)/(0.5*(rightCell%length(idx)+midCell%length(idx)))
        midCell%sb(:,:,idx) = (sign(UP,sR)+sign(UP,sL))*abs(sR)*abs(sL)/(abs(sR)+abs(sL)+SMV)
    end subroutine VanLeerLimiter
end module Tools

!--------------------------------------------------
!>Flux calculation
!--------------------------------------------------
module Flux
    use Tools
    implicit none
    integer(KREAL), parameter                           :: MNUM = 6 !Number of normal velocity moments
    integer(KREAL), parameter                           :: MTUM = 4 !Number of tangential velocity moments

contains
    !--------------------------------------------------
    !>Calculate flux of inner interface
    !>@param[in]    leftCell  :cell left to the target interface
    !>@param[inout] face      :the target interface
    !>@param[in]    rightCell :cell right to the target interface
    !>@param[in]    idx       :index indicating i or j direction
    !--------------------------------------------------
    subroutine CalcFlux(leftCell,face,rightCell,idx)
        type(CellCenter), intent(in)                    :: leftCell,rightCell
        type(CellInterface), intent(inout)              :: face
        integer(KINT), intent(in)                       :: idx
        real(KREAL), allocatable, dimension(:,:)        :: vn,vt !normal and tangential micro velocity
        real(KREAL), allocatable, dimension(:,:)        :: h,b !Distribution function at the interface
        real(KREAL), allocatable, dimension(:,:)        :: H0,B0 !Maxwellian distribution function
        real(KREAL), allocatable, dimension(:,:)        :: H_plus,B_plus !Shakhov part of the equilibrium distribution
        real(KREAL), allocatable, dimension(:,:)        :: sh,sb !Slope of distribution function at the interface
        integer(KINT), allocatable, dimension(:,:)      :: delta !Heaviside step function
        real(KREAL)                                     :: conVars(4),prim(4) !Conservative and primary variables at the interface
        real(KREAL)                                     :: qf(2) !Heat flux in normal and tangential direction
        real(KREAL)                                     :: sw(4) !Slope of conVars
        real(KREAL)                                     :: aL(4),aR(4),aT(4) !Micro slope of Maxwellian distribution, left,right and time.
        real(KREAL)                                     :: Mu(0:MNUM),MuL(0:MNUM),MuR(0:MNUM),Mv(0:MTUM),Mxi(0:2) !<u^n>,<u^n>_{>0},<u^n>_{<0},<v^m>,<\xi^l>
        real(KREAL)                                     :: Mau0(4),MauL(4),MauR(4),MauT(4) !<u\psi>,<aL*u^n*\psi>,<aR*u^n*\psi>,<A*u*\psi>
        real(KREAL)                                     :: tau !Collision time
        real(KREAL)                                     :: Mt(5) !Some time integration terms
        integer(KINT)                                   :: i,j

        !--------------------------------------------------
        !Prepare
        !--------------------------------------------------
        !Allocate array
        allocate(vn(uNum,vNum))
        allocate(vt(uNum,vNum))
        allocate(delta(uNum,vNum))
        allocate(h(uNum,vNum))
        allocate(b(uNum,vNum))
        allocate(sh(uNum,vNum))
        allocate(sb(uNum,vNum))
        allocate(H0(uNum,vNum))
        allocate(B0(uNum,vNum))
        allocate(H_plus(uNum,vNum))
        allocate(B_plus(uNum,vNum))

        !Convert the velocity space to local frame
        vn = uSpace*face%cosx+vSpace*face%cosy
        vt =-uSpace*face%cosy+vSpace*face%cosx

        !Heaviside step function
        delta = (sign(UP,vn)+1)/2

        !--------------------------------------------------
        !Reconstruct initial distribution at interface
        !--------------------------------------------------
        h = (leftCell%h+0.5*leftCell%length(idx)*leftCell%sh(:,:,idx))*delta+&
            (rightCell%h-0.5*rightCell%length(idx)*rightCell%sh(:,:,idx))*(1-delta)
        b = (leftCell%b+0.5*leftCell%length(idx)*leftCell%sb(:,:,idx))*delta+&
            (rightCell%b-0.5*rightCell%length(idx)*rightCell%sb(:,:,idx))*(1-delta)
        sh = leftCell%sh(:,:,idx)*delta+rightCell%sh(:,:,idx)*(1-delta)
        sb = leftCell%sb(:,:,idx)*delta+rightCell%sb(:,:,idx)*(1-delta)

        !--------------------------------------------------
        !Obtain macroscopic variables
        !--------------------------------------------------
        !Conservative variables w_0 at interface
        conVars(1) = sum(weight*h)
        conVars(2) = sum(weight*vn*h)
        conVars(3) = sum(weight*vt*h)
        conVars(4) = 0.5*(sum(weight*(vn**2+vt**2)*h)+sum(weight*b))

        !Convert to primary variables
        prim = GetPrimary(conVars)

        !--------------------------------------------------
        !Calculate a^L,a^R
        !--------------------------------------------------
        sw = (conVars-LocalFrame(leftCell%conVars,face%cosx,face%cosy))/(0.5*leftCell%length(idx)) !left slope of conVars
        aL = MicroSlope(prim,sw) !calculate a^L

        sw = (LocalFrame(rightCell%conVars,face%cosx,face%cosy)-conVars)/(0.5*rightCell%length(idx)) !right slope of conVars
        aR = MicroSlope(prim,sw) !calculate a^R

        !--------------------------------------------------
        !Calculate time slope of conVars and A
        !--------------------------------------------------
        !<u^n>,<v^m>,<\xi^l>,<u^n>_{>0},<u^n>_{<0}
        call CalcMoment(prim,Mu,Mv,Mxi,MuL,MuR) 

        MauL = Moment_auvxi(aL,MuL,Mv,Mxi,1,0) !<aL*u*\psi>_{>0}
        MauR = Moment_auvxi(aR,MuR,Mv,Mxi,1,0) !<aR*u*\psi>_{<0}

        sw = -prim(1)*(MauL+MauR) !Time slope of conVars
        aT = MicroSlope(prim,sw) !Calculate A

        !--------------------------------------------------
        !Calculate collision time and some time integration terms
        !--------------------------------------------------
        tau = GetTau(prim)

        Mt(4) = tau*(1.0-exp(-dt/tau))
        Mt(5) = -tau*dt*exp(-dt/tau)+tau*Mt(4)
        Mt(1) = dt-Mt(4)
        Mt(2) = -tau*Mt(1)+Mt(5) 
        Mt(3) = 0.5*dt**2-tau*Mt(1)

        !--------------------------------------------------
        !Calculate the flux of conservative variables related to g0
        !--------------------------------------------------
        Mau0 = Moment_uvxi(Mu,Mv,Mxi,1,0,0) !<u*\psi>
        MauL = Moment_auvxi(aL,MuL,Mv,Mxi,2,0) !<aL*u^2*\psi>_{>0}
        MauR = Moment_auvxi(aR,MuR,Mv,Mxi,2,0) !<aR*u^2*\psi>_{<0}
        MauT = Moment_auvxi(aT,Mu,Mv,Mxi,1,0) !<A*u*\psi>

        face%flux = Mt(1)*prim(1)*Mau0+Mt(2)*prim(1)*(MauL+MauR)+Mt(3)*prim(1)*MauT

        !--------------------------------------------------
        !Calculate the flux of conservative variables related to g+ and f0
        !--------------------------------------------------
        !Maxwellian distribution H0 and B0
        call DiscreteMaxwell(H0,B0,vn,vt,prim)
    
        !Calculate heat flux
        qf = GetHeatFlux(h,b,vn,vt,prim) 

        !Shakhov part H+ and B+
        call ShakhovPart(H0,B0,vn,vt,qf,prim,H_plus,B_plus)

        !Conservative flux related to g+ and f0
        face%flux(1) = face%flux(1)+Mt(1)*sum(weight*vn*H_plus)+Mt(4)*sum(weight*vn*h)-Mt(5)*sum(weight*vn**2*sh)
        face%flux(2) = face%flux(2)+Mt(1)*sum(weight*vn**2*H_plus)+Mt(4)*sum(weight*vn**2*h)-Mt(5)*sum(weight*vn**3*sh)
        face%flux(3) = face%flux(3)+Mt(1)*sum(weight*vt*vn*H_plus)+Mt(4)*sum(weight*vt*vn*h)-Mt(5)*sum(weight*vt*vn**2*sh)
        face%flux(4) = face%flux(4)+&
                        Mt(1)*0.5*(sum(weight*vn*(vn**2+vt**2)*H_plus)+sum(weight*vn*B_plus))+&
                        Mt(4)*0.5*(sum(weight*vn*(vn**2+vt**2)*h)+sum(weight*vn*b))-&
                        Mt(5)*0.5*(sum(weight*vn**2*(vn**2+vt**2)*sh)+sum(weight*vn**2*sb))

        !--------------------------------------------------
        !Calculate flux of distribution function
        !--------------------------------------------------
        face%flux_h = Mt(1)*vn*(H0+H_plus)+&
                        Mt(2)*vn**2*(aL(1)*H0+aL(2)*vn*H0+aL(3)*vt*H0+0.5*aL(4)*((vn**2+vt**2)*H0+B0))*delta+&
                        Mt(2)*vn**2*(aR(1)*H0+aR(2)*vn*H0+aR(3)*vt*H0+0.5*aR(4)*((vn**2+vt**2)*H0+B0))*(1-delta)+&
                        Mt(3)*vn*(aT(1)*H0+aT(2)*vn*H0+aT(3)*vt*H0+0.5*aT(4)*((vn**2+vt**2)*H0+B0))+&
                        Mt(4)*vn*h-Mt(5)*vn**2*sh

        face%flux_b = Mt(1)*vn*(B0+B_plus)+&
                        Mt(2)*vn**2*(aL(1)*B0+aL(2)*vn*B0+aL(3)*vt*B0+0.5*aL(4)*((vn**2+vt**2)*B0+Mxi(2)*H0))*delta+&
                        Mt(2)*vn**2*(aR(1)*B0+aR(2)*vn*B0+aR(3)*vt*B0+0.5*aR(4)*((vn**2+vt**2)*B0+Mxi(2)*H0))*(1-delta)+&
                        Mt(3)*vn*(aT(1)*B0+aT(2)*vn*B0+aT(3)*vt*B0+0.5*aT(4)*((vn**2+vt**2)*B0+Mxi(2)*H0))+&
                        Mt(4)*vn*b-Mt(5)*vn**2*sb
        
        !--------------------------------------------------
        !Final flux
        !--------------------------------------------------
        !convert to global frame
        face%flux = GlobalFrame(face%flux,face%cosx,face%cosy) 
        !Total flux
        face%flux = face%length*face%flux
        face%flux_h = face%length*face%flux_h
        face%flux_b = face%length*face%flux_b

        
        !--------------------------------------------------
        !Aftermath
        !--------------------------------------------------
        !Deallocate array
        deallocate(vn)
        deallocate(vt)
        deallocate(delta)
        deallocate(h)
        deallocate(b)
        deallocate(sh)
        deallocate(sb)
        deallocate(H0)
        deallocate(B0)
        deallocate(H_plus)
        deallocate(B_plus)
    end subroutine CalcFlux

    !--------------------------------------------------
    !>Calculate micro slope of Maxwellian distribution
    !>@param[in] prim        :primary variables
    !>@param[in] sw          :slope of conVars
    !>@return    MicroSlope  :slope of Maxwellian distribution
    !--------------------------------------------------
    function MicroSlope(prim,sw)
        real(KREAL), intent(in)                         :: prim(4),sw(4)
        real(KREAL)                                     :: MicroSlope(4)

        MicroSlope(4) = 4.0*prim(4)**2/((CK+2)*prim(1))*(2.0*sw(4)-2.0*prim(2)*sw(2)-2.0*prim(3)*sw(3)+sw(1)*(prim(2)**2+prim(3)**2-0.5*(CK+2)/prim(4)))
        MicroSlope(3) = 2.0*prim(4)/prim(1)*(sw(3)-prim(3)*sw(1))-prim(3)*MicroSlope(4)
        MicroSlope(2) = 2.0*prim(4)/prim(1)*(sw(2)-prim(2)*sw(1))-prim(2)*MicroSlope(4)
        MicroSlope(1) = sw(1)/prim(1)-prim(2)*MicroSlope(2)-prim(3)*MicroSlope(3)-0.5*(prim(2)**2+prim(3)**2+0.5*(CK+2)/prim(4))*MicroSlope(4)
    end function MicroSlope

    !--------------------------------------------------
    !>Calculate collision time
    !>@param[in] prim    :primary variables
    !>@return    GetTau  :collision time
    !--------------------------------------------------
    function GetTau(prim)
        real(KREAL), intent(in)                         :: prim(4)
        real(KREAL)                                     :: GetTau

        GetTau = MU_REF*2.0*prim(4)**(1-OMEGA)/prim(1)
    end function GetTau
    
    !--------------------------------------------------
    !>Calculate heat flux
    !>@param[in] h,b           :distribution function
    !>@param[in] vn,vt         :normal and tangential velocity
    !>@param[in] prim          :primary variables
    !>@return    GetHeatFlux   :heat flux in normal and tangential direction
    !--------------------------------------------------
    function GetHeatFlux(h,b,vn,vt,prim)
        real(KREAL), dimension(:,:), intent(in)         :: h,b
        real(KREAL), dimension(:,:), intent(in)         :: vn,vt
        real(KREAL), intent(in)                         :: prim(4)
        real(KREAL)                                     :: GetHeatFlux(2) !heat flux in normal and tangential direction

        GetHeatFlux(1) = 0.5*(sum(weight*(vn-prim(2))*((vn-prim(2))**2+(vt-prim(3))**2)*h)+sum(weight*(vn-prim(2))*b))
        GetHeatFlux(2) = 0.5*(sum(weight*(vt-prim(3))*((vn-prim(2))**2+(vt-prim(3))**2)*h)+sum(weight*(vt-prim(3))*b))
    end function GetHeatFlux

    !--------------------------------------------------
    !>calculate moments of velocity and \xi
    !>@param[in] prim :primary variables
    !>@param[out] Mu,Mv     :<u^n>,<v^m>
    !>@param[out] Mxi       :<\xi^2n>
    !>@param[out] MuL,MuR   :<u^n>_{>0},<u^n>_{<0}
    !--------------------------------------------------
    subroutine CalcMoment(prim,Mu,Mv,Mxi,MuL,MuR)
        real(KREAL), intent(in)                         :: prim(4)
        real(KREAL), intent(out)                        :: Mu(0:MNUM),MuL(0:MNUM),MuR(0:MNUM)
        real(KREAL), intent(out)                        :: Mv(0:MTUM)
        real(KREAL), intent(out)                        :: Mxi(0:2)
        integer :: i

        !Moments of normal velocity
        MuL(0) = 0.5*erfc(-sqrt(prim(4))*prim(2))
        MuL(1) = prim(2)*MuL(0)+0.5*exp(-prim(4)*prim(2)**2)/sqrt(PI*prim(4))
        MuR(0) = 0.5*erfc(sqrt(prim(4))*prim(2))
        MuR(1) = prim(2)*MuR(0)-0.5*exp(-prim(4)*prim(2)**2)/sqrt(PI*prim(4))

        do i=2,MNUM
            MuL(i) = prim(2)*MuL(i-1)+0.5*(i-1)*MuL(i-2)/prim(4)
            MuR(i) = prim(2)*MuR(i-1)+0.5*(i-1)*MuR(i-2)/prim(4)
        end do

        Mu = MuL+MuR

        !Moments of tangential velocity
        Mv(0) = 1.0
        Mv(1) = prim(3)

        do i=2,MTUM
            Mv(i) = prim(3)*Mv(i-1)+0.5*(i-1)*Mv(i-2)/prim(4)
        end do

        !Moments of \xi
        Mxi(0) = 1.0 !<\xi^0>
        Mxi(1) = 0.5*CK/prim(4) !<\xi^2>
        Mxi(2) = CK*(CK+2.0)/(4.0*prim(4)**2) !<\xi^4>
    end subroutine CalcMoment

    !--------------------------------------------------
    !>Calculate <a*u^\alpha*v^\beta*\psi>
    !>@param[in] a          :micro slope of Maxwellian
    !>@param[in] Mu,Mv      :<u^\alpha>,<v^\beta>
    !>@param[in] Mxi        :<\xi^l>
    !>@param[in] alpha,beta :exponential index of u and v
    !>@return    Moment_auvxi  :moment of <a*u^\alpha*v^\beta*\psi>
    !--------------------------------------------------
    function Moment_auvxi(a,Mu,Mv,Mxi,alpha,beta)
        real(KREAL), intent(in)                         :: a(4)
        real(KREAL), intent(in)                         :: Mu(0:MNUM),Mv(0:MTUM),Mxi(0:2)
        integer(KINT), intent(in)                       :: alpha,beta
        real(KREAL)                                     :: Moment_auvxi(4)

        Moment_auvxi = a(1)*Moment_uvxi(Mu,Mv,Mxi,alpha+0,beta+0,0)+&
                    a(2)*Moment_uvxi(Mu,Mv,Mxi,alpha+1,beta+0,0)+&
                    a(3)*Moment_uvxi(Mu,Mv,Mxi,alpha+0,beta+1,0)+&
                    0.5*a(4)*Moment_uvxi(Mu,Mv,Mxi,alpha+2,beta+0,0)+&
                    0.5*a(4)*Moment_uvxi(Mu,Mv,Mxi,alpha+0,beta+2,0)+&
                    0.5*a(4)*Moment_uvxi(Mu,Mv,Mxi,alpha+0,beta+0,2)
    end function Moment_auvxi

    !--------------------------------------------------
    !>Calculate <u^\alpha*v^\beta*\xi^\delta*\psi>
    !>@param[in] Mu,Mv      :<u^\alpha>,<v^\beta>
    !>@param[in] Mxi        :<\xi^delta>
    !>@param[in] alpha,beta :exponential index of u and v
    !>@param[in] delta      :exponential index of \xi
    !>@return    Moment_uvxi :moment of <u^\alpha*v^\beta*\xi^\delta*\psi>
    !--------------------------------------------------
    function Moment_uvxi(Mu,Mv,Mxi,alpha,beta,delta)
        real(KREAL), intent(in)                         :: Mu(0:MNUM),Mv(0:MTUM),Mxi(0:2)
        integer(KINT), intent(in)                       :: alpha,beta,delta
        real(KREAL)                                     :: Moment_uvxi(4)

        Moment_uvxi(1) = Mu(alpha)*Mv(beta)*Mxi(delta/2)
        Moment_uvxi(2) = Mu(alpha+1)*Mv(beta)*Mxi(delta/2)
        Moment_uvxi(3) = Mu(alpha)*Mv(beta+1)*Mxi(delta/2)
        Moment_uvxi(4) = 0.5*(Mu(alpha+2)*Mv(beta)*Mxi(delta/2)+Mu(alpha)*Mv(beta+2)*Mxi(delta/2)+Mu(alpha)*Mv(beta)*Mxi((delta+2)/2))
    end function Moment_uvxi
end module Flux