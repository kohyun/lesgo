!**********************************************************************
module cylinder_skew_param
!**********************************************************************
use types, only : rprec
use param, only : pi
use cylinder_skew_base_ls
use io, only : write_tecplot_header_xyline, write_tecplot_header_ND
use io, only : write_real_data, write_real_data_1D, write_real_data_2D, write_real_data_3D

implicit none

save 

$if ($MPI)
  !--this dimensioning adds a ghost layer for finite differences
  !--its simpler to have all arrays dimensioned the same, even though
  !  some components do not need ghost layer
  $define $lbz 0
$else
  $define $lbz 1
$endif

!  cs{0,1} all correspond to vectors with the origin at the
!  corresponding coordinate system
type(cs0), target, allocatable, dimension(:,:,:) :: gcs_t
type(cs1) :: lcs_t, slcs_t, sgcs_t, ecs_t
!type(cs2), allocatable, dimension(:) :: lgcs_t
!type(cs2), allocatable, dimension(:,:) ::  ebgcs_t, etgcs_t ! Shape (ntree, ngen)
!type(rot), allocatable, dimension(:) :: zrot_t
!  vectors do not have starting point a origin of corresponding
!  coordinate system
type(vector) :: vgcs_t

logical :: DIST_CALC=.true.

real(rprec), parameter :: BOGUS = 1234567890._rprec
real(rprec), parameter :: iBOGUS = 1234567890
real(rprec), parameter :: eps = 1.e-12
real(rprec), parameter, dimension(3) :: zrot_axis = (/0.,0.,1./)

!real(rprec), dimension(3,ntree) :: origin

logical :: in_cir, in_cyl
logical :: in_cyl_top, in_cyl_bottom
logical :: above_cyl, below_cyl
logical :: in_bottom_surf, btw_planes

integer, dimension(3) :: cyl_loc

!integer, allocatable, dimension(:) :: gen_ntrunk, gen_ncluster
!real(rprec), allocatable, dimension(:) :: crad, clen, rad_offset

real(rprec) :: circk, dist, theta
real(rprec) :: eck

end module cylinder_skew_param

!**************************************************************
program cylinder_skew_pre_ls
!***************************************************************
$if ($MPI)
use param, only : coord
$endif
use cylinder_skew_param, only : DIST_CALC, ntree
implicit none

integer :: nt

call initialize()
!  Loop over all trees
do nt = 1, ntree
  
  $if ($DEBUG)
  if(coord == 0) write(*,*) 'Tree id : ', nt
  $endif
  
  !!$if ($RNS_LS)
  !! if(coord == 0) call rns_planes(nt)
  !!$endif
   
  if(DIST_CALC) call main(nt)
  
enddo 

!  Uses global tree info from ebgcs_t and etgcs_t to
!call compute_chi()

call finalize()

write(*,*) 'Program completed successfully.'
stop

end program cylinder_skew_pre_ls

!**********************************************************************
subroutine initialize()
!**********************************************************************
$if ($MPI)
use mpi_defs
use param, only : coord
$endif
use cylinder_skew_param

implicit none

integer :: ng,nt,i,j,k,istart,iend
real(rprec) :: gen_scale_fact

call initialize_mpi ()
call allocate_arrays()
call fill_tree_array()
call generate_grid()

!  Initialize the distance function
gcs_t(:,:,:)%phi = BOGUS
!!  Set lower level
!gcs_t(:,:,0)%phi = -BOGUS
gcs_t(:,:,:)%brindex=1

!  Initialize the iset flag
gcs_t(:,:,:)%iset=0

!  Initialize the point to surface association
gcs_t(:,:,:)%itype=-1 !  0 - bottom, 1 - elsewhere

if(use_bottom_surf) then
  gcs_t(:,:,:)%itype=0
!  Loop over all global coordinates
  do k=$lbz,Nz
    gcs_t(:,:,k)%phi = gcs_t(:,:,k)%xyz(3) - z_bottom_surf   
    if(gcs_t(1,1,k)%phi <= 0.) then 
        gcs_t(:,:,k)%brindex = -1
	endif
   
  enddo
endif
  


!  Set cylinder parameters for all generations

                  
  !!$if ($DEBUG)
  !!if (coord == 0) then
  !!  write(*,*) 'skew_angle : ', skew_angle
  !!  write(*,*) 'skew_anlge (deg) : ', skew_angle*180./pi
  !!  write(*,*) 'ntrunk 	 : ', ntrunk
  !!  write(*,*) 'crad 	 : ', crad
  !!  write(*,*) 'clen 	 : ', clen
  !!  write(*,*) 'rad_offset : ', rad_offset
  !!endif
  !!$endif

!!  Set rotation angle about z-axis with which the skew angle is applied 
!  do ng=1,ngen
!    zrot_t(ng)%angle(:)=0._rprec
!  enddo

!!  Do for the 1st generation (ng = 1)
!  do nt=1,ntrunk
!    zrot_t(1)%angle(nt) = zrot_angle + 2.*pi*(nt-1)/ntrunk
!    zrot_t(1)%axis(:,nt) = (/dcos(zrot_t(1)%angle(nt)+pi/2.),dsin(zrot_t(1)%angle(nt)+pi/2.),0._rprec/)
!    
!    $if ($DEBUG)
!    if(coord == 0) then
!      write(*,*) 'zrot_t(1)%angle(nt) : ', zrot_t(1)%angle(nt)*180./pi
!      write(*,*) 'zrot_t(1)%axis(:,nt) : ', zrot_t(1)%axis(:,nt)
!    endif
!    $endif
!    
!  enddo


!!  Do for the 1st generation (ng = 1)
!do nt=1,ntrunk
!!  Set the local coordinate system
!  lgcs_t(1)%xyz(:,nt) = origin(:,ntr)
!  lgcs_t(1)%xyz(1,nt) = lgcs_t(1)%xyz(1,nt) + rad_offset(1)*dcos(zrot_t(1)%angle(nt))
!  lgcs_t(1)%xyz(2,nt) = lgcs_t(1)%xyz(2,nt) + rad_offset(1)*dsin(zrot_t(1)%angle(nt))

!  $if ($DEBUG)
!  if(coord == 0 ) then
!    write(*,*) ''
!    write(*,*) 'nt = ', nt
!    write(*,*) 'origin : ', origin(:,ntr)
!    write(*,*) 'lgcs_t(1)%xyz(:,nt) : ', lgcs_t(1)%xyz(:,nt)
!  endif
!  $endif

!  !  Set the center point of the bottom ellipse
!  ebgcs_t(ntr,1)%xyz(:,nt)=lgcs_t(1)%xyz(:,nt)
!  
!  
!  !  Compute the center point of the top ellipse in the gcs
!  call rotation_axis_vector_3d(zrot_t(1)%axis(:,nt), &
!    skew_angle, &
!    (/0._rprec, 0._rprec, clen(1)/), &
!    etgcs_t(ntr,1)%xyz(:,nt))
!  etgcs_t(ntr,1)%xyz(:,nt) = etgcs_t(ntr,1)%xyz(:,nt) + ebgcs_t(ntr,1)%xyz(:,nt)
!  
!  $if ($DEBUG)
!    write(*,*) 'ebgcs_t(1,1)%xyz(:,nt) : ', ebgcs_t(ntr,1)%xyz(:,nt)
!    write(*,*) 'etgcs_t(1,1)%xyz(:,nt) : ', etgcs_t(ntr,1)%xyz(:,nt)
!  $endif

!enddo

!if(ngen > 1) then

!  !  Set the lgcs for the new generation
!  do ng=2,ngen
!  !  Set the rotation angle for each trunk. The first trunk has the same as the first generation
!    i=1
!    do nt=1,gen_ntrunk(ng)
!      zrot_t(ng)%angle(nt) = zrot_t(1)%angle(i)
!      if(mod(ng,2)==0) zrot_t(ng)%angle(nt) = zrot_t(ng)%angle(nt) + pi
!      zrot_t(ng)%axis(:,nt) = (/dcos(zrot_t(ng)%angle(nt)+pi/2.),dsin(zrot_t(ng)%angle(nt)+pi/2.),0._rprec/)
!      i = i + 1
!      if(i > ntrunk) i = 1
!    enddo

!  !  Set the local origin in the gcs
!  !  Set the lgcs for the new generation
!    do j=1,gen_ntrunk(ng - 1)

!      istart = (j-1)*ntrunk + 1
!      iend   = istart + (ntrunk -1)

!      $if ($DEBUG)
!        write(*,*) 
!        write(*,*) 'istart : ', istart
!        write(*,*) 'iend   : ', iend
!      $endif

!      do i=istart,iend
!        lgcs_t(ng)%xyz(:,i) = etgcs_t(ntr,ng-1)%xyz(:,j)
!        lgcs_t(ng)%xyz(1,i) = lgcs_t(ng)%xyz(1,i) + rad_offset(ng)*dcos(zrot_t(ng)%angle(i))
!        lgcs_t(ng)%xyz(2,i) = lgcs_t(ng)%xyz(2,i) + rad_offset(ng)*dsin(zrot_t(ng)%angle(i))
!      enddo

!    enddo
!  
!    !  Set top and bottom of the cylinder
!    do nt=1,gen_ntrunk(ng)
!      !  Set the center point of the bottom ellipse
!      ebgcs_t(ntr,ng)%xyz(:,nt)=lgcs_t(ng)%xyz(:,nt)
!      !  Compute the center point of the top ellipse in the gcs
!      call rotation_axis_vector_3d (zrot_t(ng)%axis(:,nt), &
!	    skew_angle, &
!	    (/0._rprec, 0._rprec, clen(ng)/),&
!	    etgcs_t(ntr,ng)%xyz(:,nt))
!        etgcs_t(ntr,ng)%xyz(:,nt) = etgcs_t(ntr,ng)%xyz(:,nt) + ebgcs_t(ntr,ng)%xyz(:,nt)
!    enddo

!  enddo


!endif

!  Top and bottom z-plane in gcs (same for all cylinders in generation)
do ng=1,ngen

  if(coord == 0) then
    write(*,*) 'generation # : ', ng
    write(*,*) 'bplane and tplane = ', tr_t(1)%gen_t(ng)%bplane, tr_t(1)%gen_t(ng)%tplane
  endif

enddo


return 

contains

!**********************************************************************
subroutine fill_tree_array()
!**********************************************************************

implicit none

integer :: nc, nb, nc_g1
real(rprec) :: angle

allocate(tr_t(ntree))

!  Set the tree origins
tr_t(1)%origin = (/ L_x/2., L_y/2., z_bottom_surf /)
!tr_t(2)%origin = (/ 0._rprec, L_y, z_bottom_surf /)
!tr_t(3)%origin = (/ 0._rprec, 0._rprec, z_bottom_surf /)
!tr_t(4)%origin = (/ L_x, 0._rprec, z_bottom_surf /)
!tr_t(5)%origin = (/ L_x, L_y, z_bottom_surf /)
!tr_t(6)%origin = (/ L_x/2, 3./2.*L_y, z_bottom_surf /)
!tr_t(7)%origin = (/ L_x/2, -1./2.*L_y, z_bottom_surf /)

!  Set the number of generations in the tree
tr_t%ngen = ngen
tr_t%ngen_reslv = ngen_reslv

!  Allocate the number of clusters in the generation
do nt=1,ntree

  allocate(tr_t(nt)%gen_t( tr_t(nt)%ngen ))
  
  do ng=1, tr_t(nt)%ngen
    
    !  Set the number of clusters for the generation
    tr_t(nt)%gen_t(ng)%ncluster = nbranch**(ng - 1)
    
    allocate( tr_t(nt)%gen_t(ng)%cl_t( tr_t(nt)%gen_t(ng)%ncluster ))
    
    do nc=1, tr_t(nt)%gen_t(ng)%ncluster
    
        tr_t(nt)%gen_t(ng)%cl_t(nc)%nbranch = nbranch
        
        allocate( tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t( tr_t(nt)%gen_t(ng)%cl_t(nc)%nbranch ))
     
    enddo
    
  enddo
 
enddo

do nt = 1, ntree
    
    do ng = 1, tr_t(nt)%ngen
    
        gen_scale_fact = scale_fact**(ng-1)
            
        do nc = 1, tr_t(nt)%gen_t(ng)%ncluster

            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % offset = gen_scale_fact*offset
            
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % d = gen_scale_fact*d
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % l = gen_scale_fact*l
            
            ! Ellipse minor axis
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % b = &
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % d / 2._rprec 
            
            ! Ellipse major axis
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % a = &
            tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t % b/dcos(skew_angle) 
            
            do nb = 1, tr_t(nt) % gen_t(ng) % cl_t(nc) % nbranch

                angle =  zrot_angle + &
                    2.*pi*(nb-1)/(tr_t(nt) % gen_t(ng) % cl_t(nc) % nbranch) + &
                    (ng - 1)*pi ! Rotate 180 degrees for each generation
                    
                tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % angle = angle
                   
                
                tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % skew_axis = &
                    (/ dcos(angle +pi/2.), dsin(angle + pi/2.), 0._rprec/)
                        
                tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % skew_angle = skew_angle         
                  
                 
                 
            enddo
        
        enddo
        
    enddo
    
enddo

do nt = 1, ntree

    do ng=1, tr_t(nt)%ngen
 
        !  Set cluster id for ng+1 generation
        nc_g1 = 0
        
        do nc = 1, tr_t(nt)%gen_t(ng)%ncluster
            
            !  Set cluster origin to tree origin
            if( ng == 1 ) tr_t(nt) % gen_t(ng) % cl_t(nc) % origin = tr_t(nt) % origin
            
            do nb = 1, tr_t(nt)%gen_t(ng)%cl_t(nc)%nbranch
                
                !  Update cluster id for ng+1 generation
                nc_g1 = nc_g1 + 1
                    
                tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % bot = &
                    tr_t(nt) % gen_t(ng) % cl_t(nc) % origin
                
                tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % bot(1) = &
                    tr_t(nt) % gen_t(ng) % cl_t(nc) % origin(1) + &          
                    tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % offset * &
                    dcos(tr_t(nt) % gen_t(ng) %cl_t(nc) % br_t(nb) % angle)
                
                tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % bot(2) = &
                    tr_t(nt) % gen_t(ng) % cl_t(nc) % origin(2) + &
                    tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % offset * &
                    dsin(tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % angle)
                   
                call rotation_axis_vector_3d( tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % skew_axis, &
                    tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % skew_angle, &
                    (/ 0._rprec, 0._rprec, tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % l /), &
                    tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % top )
                
                tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % top = & 
                    tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % top + &
                    tr_t(nt)%gen_t(ng)%cl_t(nc)% br_t(nb) % bot
                
            !  Now set the cluster origin of the ng+1 cluster (with nc = nb)
                if ( ng < tr_t(nt)%ngen ) then
                    tr_t(nt) % gen_t(ng+1) % cl_t(nc_g1) % origin = &
                    tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % top
                endif

 
            enddo
                   
        enddo
        
        !  Set the top and bottom plane of the generation - this assumes that all 
        !  branches are the same height!      
        tr_t(nt) % gen_t(ng) % bplane = tr_t(nt) % gen_t(ng) % cl_t(1) % br_t(1) % bot(3)
        tr_t(nt) % gen_t(ng) % tplane = tr_t(nt) % gen_t(ng) % cl_t(1) % br_t(1) % top(3)
    
    enddo
    
enddo

return
end subroutine fill_tree_array



!**********************************************************************
subroutine allocate_arrays()
!**********************************************************************

implicit none

!  Allocate x,y,z for all coordinate systems
allocate(gcs_t(nx+2,ny,$lbz:nz))

!allocate(lgcs_t(ngen), zrot_t(ngen))

!!  Center of bottom and top ellipse of each cylinder
!allocate(ebgcs_t(ntree,ngen), &
!  etgcs_t(ntree, ngen))

!allocate(a(ngen), &
!  b(ngen), &
!  crad(ngen),&
!  clen(ngen), &
!  rad_offset(ngen), &
!  tplane(ngen), &
!  bplane(ngen), &
!  gen_ntrunk(ngen), &
!  gen_ncluster(ngen))

!do ng=1,ngen
!  gen_ntrunk(ng) = ntrunk**ng
!  gen_ncluster(ng) = ntrunk**(ng-1)
!enddo

!do ng=1,ngen
!  allocate(lgcs_t(ng)%xyz(3,gen_ntrunk(ng)))
!  
!  do nt=1,ntree
!    allocate(ebgcs_t(nt,ng)%xyz(3,gen_ntrunk(ng)))
!    allocate(etgcs_t(nt,ng)%xyz(3,gen_ntrunk(ng)))
!  enddo
!  
!  allocate(zrot_t(ng)%angle(gen_ntrunk(ng)))
!  allocate(zrot_t(ng)%axis(3,gen_ntrunk(ng)))
!enddo

return
end subroutine allocate_arrays

!**********************************************************************
subroutine generate_grid()
!**********************************************************************
! This subroutine generates the xyz values on all the points in the domain
! (global coordinate system) in gcs_t using the grid generation routine
! grid_build()
!
use param, only : nproc, coord
use grid_defs

implicit none

if(.not. grid_built) call grid_build()

do k=$lbz,nz
  do j=1,ny
    do i=1,nx+2
      gcs_t(i,j,k)%xyz(1) = x(i)
      gcs_t(i,j,k)%xyz(2) = y(j)
      gcs_t(i,j,k)%xyz(3) = z(k)
    enddo
  enddo
enddo
     
return
end subroutine generate_grid

end subroutine initialize

!!**********************************************************************
!subroutine rns_planes(ntr)
!!**********************************************************************
!use types, only : rprec
!use cylinder_skew_param, only : ngen,ntrunk,origin,skew_angle,clen,crad, &
!  lgcs_t, etgcs_t
!implicit none

!integer, intent(IN) :: ntr

!real(rprec), parameter :: alpha=1._rprec

!character (64) :: fname, temp

!integer :: ng,ntc
!integer :: ntrunk_cluster, indx, nplanes

!real(rprec) :: h,w,xmin,xmax,ymin,ymax,zmin,zmax
!real(rprec), dimension(3) :: corigin
!real(rprec), dimension(9) :: bp

!!  Open file which to write rns plane data
!write (fname,*) 'cylinder_skew_rns_planes_ls.out'
!fname = trim(adjustl(fname)) 
!write (temp, '(".t",i0)') ntr
!fname = trim (fname) // temp

!open (unit = 2, file = fname, status='unknown',form='formatted', &
!      action='write',position='rewind')

!!  Open file which to write rns plane data
!write (fname,*) 'rns_planes_ls.out'
!fname = trim(adjustl(fname)) 
!write (temp, '(".t",i0)') ntr
!fname = trim (fname) // temp

!open (unit = 3, file = fname, status='unknown',form='unformatted', &
!      action='write',position='rewind')

!nplanes = 0
!do ng=1,ngen
!  ntrunk_cluster=ntrunk**(ng-1)
!  do ntc=1,ntrunk_cluster
!    nplanes = nplanes + 1
!  enddo
!enddo

!!write(3,'(1i)') nplanes
!write(3) nplanes

!indx = 0

!do ng=1,ngen
!  !  Compute projected area to be that of a single trunk-cluster (Ap = h*w)
!  h = clen(ng)*cos(skew_angle) ! height
!  w = 2._rprec*crad(ng)*ntrunk ! width

!  ntrunk_cluster=ntrunk**(ng-1)


!  do ntc=1,ntrunk_cluster
!    indx = indx + 1
!    if(ng == 1) then
!      corigin = origin(:,ntr) !  Use tree origin
!    else 
!      corigin = etgcs_t(ntr,ng-1)%xyz(:,ntc)  ! Use top of ellipse below
!    endif 
!    xmin = corigin(1) - alpha*w 
!    xmax = xmin
!    ymin = corigin(2) - w/2._rprec
!    ymax = corigin(2) + w/2._rprec
!    zmin = corigin(3) 
!    zmax = corigin(3) + h

!    write(2,'(2i6,6f12.6)') ng, ntc, xmin, xmax, ymin, ymax, zmin, zmax

!    bp = (/ xmin, ymin, zmin, xmin, ymin, zmax, xmin, ymax, zmax /)
!    !write(3,'(1i,9f12.6)') indx, bp
!	write(3) indx, bp

!  enddo
!enddo
!close(2)
!close(3)

!return
!end subroutine rns_planes

!**********************************************************************
subroutine main(nt)
!**********************************************************************
use cylinder_skew_param

implicit none

integer, intent(IN) :: nt

integer :: ng, nc, nb,i,j,k
!  Loop over all global coordinates
do k=$lbz,Nz

    do j=1,ny

        do i=1,nx+2

            do ng = 1, tr_t(nt)%ngen_reslv
        
                do nc = 1, tr_t(nt)%gen_t(ng)%ncluster

                    do nb=1, tr_t(nt)%gen_t(ng)%cl_t(nc)%nbranch

                        if(gcs_t(i,j,k)%phi > 0) then
                            call pt_loc(nt,ng,nc,nb,i,j,k)
                            call point_dist(nt,ng,nc,nb,i,j,k)
                            call set_sign(i,j,k)
                        endif
                
                    enddo
            
                enddo
            enddo
        enddo
    enddo
enddo

return
end subroutine main


!**********************************************************************
subroutine pt_loc(nt,ng,nc,nb,i,j,k)
!**********************************************************************

use cylinder_skew_param

implicit none

integer, intent(IN) :: nt,ng,nc,nb,i,j,k

real(rprec) :: a, b, bplane, tplane

!  Intialize flags
btw_planes=.false.
in_cir=.false.
in_cyl=.false.
in_bottom_surf = .false.
in_cyl_top=.false.
in_cyl_bottom=.false.

!  Set temporary values
a = tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%a
b = tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%b
bplane = tr_t(nt)%gen_t(ng)%bplane
tplane = tr_t(nt)%gen_t(ng)%tplane

!  Also check if point is below bottom surface
if(use_bottom_surf .and. ng == 1) then
  if(gcs_t(i,j,k)%xyz(3) <= z_bottom_surf) in_bottom_surf = .true.
endif

!  First check if points are between the top and bottom planes in the z - gcs
if(gcs_t(i,j,k)%xyz(3) >= bplane .and. gcs_t(i,j,k)%xyz(3) <= tplane) then
  btw_planes=.true.
elseif(gcs_t(i,j,k)%xyz(3) > tplane) then
!  Check if point is below bottom ellipse
  above_cyl = .true.
elseif(gcs_t(i,j,k)%xyz(3) < bplane) then
!  Check if point is below bottom ellipse
  below_cyl = .true.
else
  write(*,*) 'Error in pt_loc: cannot be anywhere else'
  stop
endif
      
!  Compute vector to point in the gcs from the lcs 
vgcs_t%xyz = gcs_t(i,j,k)%xyz - tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%bot
!  Rotate gcs vector into local coordinate system
call rotation_axis_vector_3d(tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%skew_axis, &
  -tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%skew_angle, &
  vgcs_t%xyz, lcs_t%xyz)

!  Check if the point lies in the cylinder circle
 circk = lcs_t%xyz(1)**2 + lcs_t%xyz(2)**2
if(circk <= (tr_t(nt) % gen_t(ng) % cl_t(nc) % br_t(nb) % d / 2._rprec)**2) in_cir = .true.

!  Check if point is in cylinder
if(btw_planes .and. in_cir) in_cyl = .true.

!  Check if point lies in top ellipse
vgcs_t%xyz = gcs_t(i,j,k)%xyz - tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%top
call rotation_axis_vector_3d(zrot_axis, &
  -tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%angle, &
  vgcs_t%xyz, &
  ecs_t%xyz)
  
eck = ecs_t%xyz(1)**2/(a**2) + ecs_t%xyz(2)**2/(b**2)
    
if(eck <= 1 .and. gcs_t(i,j,k)%xyz(3) > (tplane + bplane)/2.) in_cyl_top=.true. !  Could be below or above

!  Check if point lies in bottom ellipse
vgcs_t%xyz = gcs_t(i,j,k)%xyz - tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%bot
call rotation_axis_vector_3d(zrot_axis, &
  -tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%angle, &
  vgcs_t%xyz, &
  ecs_t%xyz)
eck = ecs_t%xyz(1)**2/(a**2) + ecs_t%xyz(2)**2/(b**2)
if(eck <= 1 .and. gcs_t(i,j,k)%xyz(3) < (tplane + bplane)/2.) in_cyl_bottom=.true. !  Could be below or above

return
end subroutine pt_loc

!**********************************************************************
subroutine point_dist(nt,ng,nc,nb,i,j,k)
!**********************************************************************
use cylinder_skew_param

implicit none

integer, intent(IN) :: nt,ng,nc,nb,i,j,k
real(rprec) :: atan4, a, b, bplane, tplane

!  Set temporary values
a = tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%a
b = tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%b
bplane = tr_t(nt)%gen_t(ng)%bplane
tplane = tr_t(nt)%gen_t(ng)%tplane

!  Compute theta value on lcs using geometry.atan4
theta = atan4(lcs_t%xyz(2),lcs_t%xyz(1))

slcs_t%xyz(1) = b*dcos(theta)
slcs_t%xyz(2) = b*dsin(theta)
slcs_t%xyz(3) = lcs_t%xyz(3)

!  Rotate the surface vector in the lcs back into the gcs
call rotation_axis_vector_3d(tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%skew_axis, & 
  tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%skew_angle,slcs_t%xyz,vgcs_t%xyz)

sgcs_t%xyz = vgcs_t%xyz + tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%bot !  Vector now corresponds with origin of gcs

!  Check if point on cylinder surface is between cutting planes
if(sgcs_t%xyz(3) >= bplane .and. sgcs_t%xyz(3) <= tplane) then

  call vector_magnitude_3d(lcs_t%xyz - slcs_t%xyz,dist)

  if(dist <= dabs(gcs_t(i,j,k)%phi)) then
    gcs_t(i,j,k)%phi = dist
    gcs_t(i,j,k)%itype = 1
    call set_iset(i,j,k)
  endif
else
  if(sgcs_t%xyz(3) >= tplane .and. .not. in_cyl_top) then

    vgcs_t%xyz = gcs_t(i,j,k)%xyz - tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%top

  !  Get vector in ellipse coordinate system
    call rotation_axis_vector_3d(zrot_axis, -tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%angle, &
        vgcs_t%xyz, ecs_t%xyz)

    call ellipse_point_dist_2D_3(a,b,ecs_t%xyz(1),ecs_t%xyz(2),eps, dist)

    call vector_magnitude_2d((/dist, ecs_t%xyz(3) /), dist)

    if(dist <= dabs(gcs_t(i,j,k)%phi)) then
      gcs_t(i,j,k)%phi = dist
      gcs_t(i,j,k)%itype = 1
      call set_iset(i,j,k)
    endif

  elseif(sgcs_t%xyz(3) <= bplane .and. .not. in_cyl_bottom) then
    vgcs_t%xyz = gcs_t(i,j,k)%xyz - tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%bot

  !  Get vector in ellipse coordinate system
    call rotation_axis_vector_3d(zrot_axis, -tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%angle, &
        vgcs_t%xyz, ecs_t%xyz)

    call ellipse_point_dist_2D_3(a,b,ecs_t%xyz(1),ecs_t%xyz(2),eps, dist)

    call vector_magnitude_2d((/dist, ecs_t%xyz(3) /), dist)

    if(dist <= dabs(gcs_t(i,j,k)%phi)) then
      gcs_t(i,j,k)%phi = dist
      gcs_t(i,j,k)%itype = 1
      call set_iset(i,j,k)
    endif

  endif 

endif

!  Check also if the point lies on the ellipses
if(in_cyl_top) then
  dist = dabs(gcs_t(i,j,k)%xyz(3) - tplane)
  if(dist <= dabs(gcs_t(i,j,k)%phi)) then
    gcs_t(i,j,k)%phi = dist
    gcs_t(i,j,k)%itype = 1
    call set_iset(i,j,k)
  endif
endif

if(in_cyl_bottom) then
  dist = dabs(gcs_t(i,j,k)%xyz(3) - bplane)
  if(dist <= dabs(gcs_t(i,j,k)%phi)) then
    gcs_t(i,j,k)%phi = dist
    gcs_t(i,j,k)%itype = 1
    call set_iset(i,j,k)
  endif
endif

return
end subroutine point_dist

!**********************************************************************
subroutine set_iset(i,j,k)
!**********************************************************************
use cylinder_skew_param, only : gcs_t

implicit none

logical, parameter :: VERBOSE=.false.
integer, intent(IN) :: i,j,k

if(gcs_t(i,j,k)%iset == 1) then
  if(VERBOSE) write(*,*) 'iset already 1 - resetting phi at i,j,k : ', i,j,k
else
  gcs_t(i,j,k)%iset = 1
endif

return
end subroutine set_iset

!**********************************************************************
subroutine set_sign(i,j,k)
!**********************************************************************
use cylinder_skew_param

implicit none

integer, intent(IN) :: i,j,k
!if(gcs_t(i,j,k)%phi > 0) then
  if(in_cyl .or. in_bottom_surf) then
    gcs_t(i,j,k)%phi = -dabs(gcs_t(i,j,k)%phi)
    gcs_t(i,j,k)%brindex = 1
  else    
    gcs_t(i,j,k)%brindex = 0
  endif
!endif
return
end subroutine set_sign

!######################################################################

!**********************************************************************
subroutine compute_chi()
!**********************************************************************
!  This subroutine filters the indicator function chi
use cylinder_skew_param
use messages
$if($MPI)
use param, only : coord, nproc
use mpi_defs, only : mpi_sync_real_array
$endif

implicit none
character (*), parameter :: sub_name = 'compute_chi'
real(rprec), dimension(:), allocatable :: z_w ! Used for checking vertical locations

integer :: i,j,k, id_gen, iface, ubz
real(rprec) :: chi_sum, bplane, tplane

allocate(z_w($lbz:nz))

$if ($MPI)
  if(coord == nproc - 1) then
    ubz = nz
  else
    ubz = nz - 1
  endif
$else
  ubz = nz
$endif

!  Create w-grid (physical grid)
do k=$lbz,nz
  z_w(k) = gcs_t(1,1,k)%xyz(3) - dz/2.
enddo

!  Do not set top most chi value; for MPI jobs
!  this is the overlap node and must be sync'd
do k=$lbz,ubz
  do j=1,ny
    do i=1,nx
!      if(gcs_t(i,j,k)%phi <= 0.) then
!  	gcs_t(i,j,k)%chi=1.
!      else
  
  !  See if points have a generation association
      call find_assoc_gen(gcs_t(i,j,k)%xyz(3), id_gen, iface)
      
      !  Assume all trees have same bplane and tplane values for all generations
      bplane = tr_t(1)%gen_t(id_gen)%bplane
      tplane = tr_t(1)%gen_t(id_gen)%tplane
      
       !write(*,*) 'gcs_t(i,j,k)%xyz(3), id_gen, iface : ', gcs_t(i,j,k)%xyz(3), id_gen, iface
      if(id_gen > ngen ) then
        call error(sub_name,'id_gen > ngen')
      endif
  
      if (iface == -1) then
  
        gcs_t(i,j,k)%chi = 0.

      elseif( 0 <= iface .and. iface <= 3) then

        if(iface == 0) then

          call filter_chi(gcs_t(i,j,k)%xyz, id_gen, filt_width, gcs_t(i,j,k)%chi)
          
        elseif(iface == 1) then
    
          !  Set z location to bottom plane of generation
          call filter_chi((/ gcs_t(i,j,k)%xyz(1), gcs_t(i,j,k)%xyz(2), bplane/), &
            id_gen, filt_width, gcs_t(i,j,k)%chi)
          !  Normalize by volume fraction
          gcs_t(i,j,k)%chi = gcs_t(i,j,k)%chi * (z_w(k+1) - bplane)/dz

        elseif(iface == 2) then
  
          call filter_chi((/ gcs_t(i,j,k)%xyz(1), gcs_t(i,j,k)%xyz(2), tplane/), id_gen, filt_width, chi_sum)
          !  Normalize by volume fraction
          chi_sum = chi_sum * (tplane - z_w(k))/dz

          call filter_chi((/ gcs_t(i,j,k)%xyz(1), gcs_t(i,j,k)%xyz(2), tplane/), id_gen+1, filt_width, gcs_t(i,j,k)%chi)
          !  Normalize by volume fraction
          gcs_t(i,j,k)%chi = chi_sum + gcs_t(i,j,k)%chi * (z_w(k+1) - tplane)/dz

        elseif(iface == 3) then
  
          call filter_chi((/ gcs_t(i,j,k)%xyz(1), gcs_t(i,j,k)%xyz(2), tplane/), id_gen, filt_width, gcs_t(i,j,k)%chi)
          !  Normalize by volume fraction
          gcs_t(i,j,k)%chi = gcs_t(i,j,k)%chi * (tplane - z_w(k))/dz
  
        endif
  
      else
   
        call error(sub_name,' iface not calculated correctly : ', iface)

      endif
    enddo
  enddo
enddo

deallocate(z_w)

!  Now must sync all overlapping nodes
$if ($MPI)
call mpi_sync_real_array(gcs_t(:,:,:)%chi)
$endif

return

end subroutine compute_chi

!**********************************************************************
subroutine find_assoc_gen(z,id_gen,iface)
!**********************************************************************
!  This subroutine finds the generation associated with a given point
!  on the uv grid (i.e. cell center). This routine biases the bottom
!  generation when an interior interface falls within a cell

!  iface - 0 (no interface), 1 (bottom of tree), 
!          2 (inter-generation interface), 3 (top of tree)

use cylinder_skew_param
implicit none

real(rprec), intent(in) :: z ! on uv grid
integer, intent(out) :: id_gen, iface

integer :: ng
real(rprec) :: zcell_bot, zcell_top, bplane, tplane

id_gen=-1
iface=-1 

zcell_bot = z - dz/2.
zcell_top = z + dz/2.

isearch_gen : do ng=1,ngen
    !  Assume all trees have same bplane and tplane values for all generations
    bplane = tr_t(1)%gen_t(ng)%bplane
    tplane = tr_t(1)%gen_t(ng)%tplane
  ! Check if bottom of generation is within cell
  if(zcell_bot < bplane .and. bplane < zcell_top) then
    if(ng==1) then
      id_gen = ng
      iface = 1
      exit isearch_gen
    else
      id_gen = ng-1
      iface = 2
      exit isearch_gen
    endif
  ! Check if top of generation is within cell
  elseif (zcell_bot < tplane .and. tplane < zcell_top ) then
    if(ng < ngen) then
      id_gen = ng
      iface = 2
      exit isearch_gen
    else
      id_gen = ng
      iface = 3
      exit isearch_gen
   endif
  elseif(bplane < z .and. z < tplane) then
	id_gen = ng
	iface = 0
	exit isearch_gen
  endif

enddo isearch_gen


return
end subroutine find_assoc_gen

!**********************************************************************
subroutine filter_chi(xyz, id_gen, delta, chi)
!**********************************************************************
!  This subroutine performs filtering in the horizontal planes
!
!  delta - filter width
!  chi   - filtered indicator function
!
use cylinder_skew_param
implicit none

real(rprec), intent(in), dimension(3) :: xyz
integer, intent(in) :: id_gen
real(rprec), intent(in) :: delta
real(rprec), intent(out) :: chi

integer :: nt, ng, nc, nb
real(rprec) :: delta2, chi_int, ds
real(rprec), dimension(3) :: xyz_c, xyz_rot

type(vector) :: lvec_t, svec_t

chi=0.

delta2 = delta*delta


!write(*,*) ' '
!write(*,*) 'id_gen, gen_ncluster(id_gen) : ', id_gen, gen_ncluster(id_gen)
do nt=1, ntree
  
  !  Loop over all branch clusters
  do nc=1,tr_t(nt)%gen_t(id_gen)%ncluster
    !  Loop over all branches within cluster
    do nb=1,tr_t(nt)%gen_t(id_gen)%cl_t(nc)%nbranch
        

 !     write(*,'(1a,3f12.6)') 'ebgcs_t(ntr,id_gen)%xyz(:,nt) : ', ebgcs_t(ntr,id_gen)%xyz(:,nt)
 !     write(*,'(1a,f12.6)') 'xyz(3) - ebgcs_t(ntr,id_gen)%xyz(3,nt) : ', xyz(3) - ebgcs_t(ntr,id_gen)%xyz(3,nt)
      !  Compute center of ellipse to average over
  
	  svec_t%xyz = tr_t(nt)%gen_t(id_gen)%cl_t(nc)%br_t(nb)%top - &
        tr_t(nt)%gen_t(id_gen)%cl_t(nc)%br_t(nb)%bot
	  
      call vector_magnitude_3d(svec_t%xyz, svec_t%mag)
      
	  ds = ( xyz(3) - tr_t(nt)%gen_t(id_gen)%cl_t(nc)%br_t(nb)%bot(3) ) / (svec_t%mag * cos(skew_angle))
	  
      xyz_c = ds * svec_t%xyz
	  
      xyz_c = xyz_c + tr_t(nt)%gen_t(id_gen)%cl_t(nc)%br_t(nb)%bot
  
  !    write(*,'(1a,3f12.6)') 'xyz ', xyz
  !    write(*,'(1a,3f12.6)') 'xyz_c : ', xyz_c
   
      !  Compute local vector
      lvec_t%xyz = xyz - xyz_c
   
  
  
   !   write(*,'(1a,f12.6)') 'zrot_t(id_gen)%angle(n)*180/pi : ', zrot_t(id_gen)%angle(n)*180./pi
      !  Perform rotation of local vector about z-axis
      call rotation_axis_vector_3d(zrot_axis, -tr_t(nt)%gen_t(id_gen)%cl_t(nc)%br_t(nb)%angle, &
        lvec_t%xyz, xyz_rot)
  
      !!  Point in rotated coordinate system
      !xyz_rot = lvec_t%xyz + xyz_c
  
    !  write(*,'(1a,3f12.6)') 'xyz_rot : ', xyz_rot
  
      !dist2 = (xyz_rot(1) - xyz_p(1))**2 + (xyz_rot(2) - xyz_p(2))**2 + (xyz_rot(3) - xyz_p(3))**2
  
      !  Perform weighted integration over ellipse
      call weighted_chi_int(tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%a, &
        tr_t(nt)%gen_t(ng)%cl_t(nc)%br_t(nb)%b, &
        xyz_rot(1), xyz_rot(2), delta, chi_int)

      chi = chi + chi_int
  
    enddo

  enddo
enddo

!  Normalize 
chi = chi/(2._rprec*pi*delta2)

return

end subroutine filter_chi

!**********************************************************************
subroutine weighted_chi_int(a,b,x,y,delta,chi)
!**********************************************************************
use types, only : rprec
!  Does not normalize
implicit none

real(rprec), intent(in) :: a,b,x,y, delta
real(rprec), intent(out) :: chi

integer, parameter :: Nx=10, Ny=10

integer :: i,j
real(rprec) :: dx, dy, a2, b2, xc, yc, delta2, dist2, ellps_val

a2 = a*a
b2 = b*b

dx = 2._rprec*a / Nx
dy = 2._rprec*b / Ny 

delta2 = delta*delta

chi=0.
do j=1,ny

  !  y-value of cell center
  yc = -b + (j - 0.5)*dy
  
  do i=1,nx
  
    !  x-value of cell center
    xc = -a + (i - 0.5)*dx 
  
	!  Compute test value for ellipse
    ellps_val = xc*xc/a2 + yc*yc/b2
  
	!  Check if cell center is inside ellipse
    if(ellps_val <= 1.) then
  
	  !  distance from cell center and specified point
      dist2 = ((xc - x)**2 + (yc - y)**2)

	  chi = chi + dx*dy*exp(-dist2/(2._rprec*delta2))
	  
	endif
	
  enddo
	
enddo

return
end subroutine weighted_chi_int


!############################################################################################################

!############################################################################################################
!**********************************************************************
subroutine finalize()
!**********************************************************************
$if ($MPI)
use mpi_defs
use param, only : nproc, coord, ierr
$endif
use cylinder_skew_param

implicit none

if(DIST_CALC) call write_output()

!  Finalize mpi communication
call MPI_FINALIZE(ierr)

return
contains

!**********************************************************************
subroutine write_output()
!**********************************************************************
use cylinder_skew_base_ls, only : brindex, phi
use grid_defs
implicit none

character (64) :: fname, temp
integer :: i,j,k

if(nproc > 1 .and. coord == 0) gcs_t(:,:,$lbz)%phi = -BOGUS

!  Open file which to write global data
write (fname,*) 'cylinder_skew_ls.dat'
fname = trim(adjustl(fname)) 

if(nproc > 1) then
  write (temp, '(".c",i0)') coord
  fname = trim (fname) // temp
endif
!  Create tecplot formatted phi and brindex field file
open (unit = 2,file = fname, status='unknown',form='formatted', &
  action='write',position='rewind')

write(2,*) 'variables = "x", "y", "z", "phi", "brindex", "itype", "chi"';

write(2,"(1a,i9,1a,i3,1a,i3,1a,i3,1a,i3)") 'ZONE T="', &

1,'", DATAPACKING=POINT, i=', Nx,', j=',Ny, ', k=', Nz+1

write(2,"(1a)") ''//adjustl('DT=(DOUBLE DOUBLE DOUBLE DOUBLE DOUBLE DOUBLE DOUBLE)')//''

do k=$lbz,nz
  do j=1,ny
    do i=1,nx
      write(2,*) gcs_t(i,j,k)%xyz(1), gcs_t(i,j,k)%xyz(2), gcs_t(i,j,k)%xyz(3), gcs_t(i,j,k)%phi, gcs_t(i,j,k)%brindex, gcs_t(i,j,k)%itype, gcs_t(i,j,k)%chi
    enddo
  enddo
enddo
close(2)

nullify(phi,brindex)
allocate(phi(nx+2,ny,$lbz:nz))
allocate(brindex(nx+2,ny,$lbz:nz))
do k=$lbz,nz
  do j = 1,ny
    do i = 1,nx+2
      phi(i,j,k) = gcs_t(i,j,k)%phi
      brindex(i,j,k) = gcs_t(i,j,k)%brindex
    enddo
  enddo
enddo

if(coord == 0) phi(:,:,$lbz) = -BOGUS

!  Open file which to write global data
write (fname,*) 'phi.out'
fname = trim(adjustl(fname)) 

if(nproc > 1) then
  write (temp, '(".c",i0)') coord
  fname = trim (fname) // temp
endif
!  Write binary data for lesgo
open (1, file=fname, form='unformatted')
if(nproc > 1) then
  write(1) phi(:,:,$lbz:nz)
else
  write(1) phi(:,:,1:nz)
endif
close (1)

!  Open file which to write global data
write (fname,*) 'brindex.out'
fname = trim(adjustl(fname)) 

if(nproc > 1) then
  write (temp, '(".c",i0)') coord
  fname = trim (fname) // temp
endif

open (1, file=fname, form='unformatted')
if(nproc > 1) then
  write(1) brindex(:,:,1:nz-1)
else
  write(1) brindex(:,:,1:nz)
endif
close (1)

!  Generate generation associations to be used in drag force calculations
!  for each generation
call gen_assoc() !  Generation data from the last tree must match that of the first

return
end subroutine write_output

!**********************************************************************
subroutine gen_assoc()
!**********************************************************************
!
!  This subroutine is used to find where each generation lives at. The
!  information created from this routine is used in lesgo for computing
!  drag force data for individual generations. In order to use this
!  capability the Makefile flag should be set to USE_CYLINDER_SKEW=yes
!           
use param, only : nz,dz

implicit none
character(64) :: fname, temp
integer :: ng, k

real(rprec) :: bplane, tplane
integer, dimension(:), allocatable :: igen, kbottom, kbottom_inside, ktop, ktop_inside
real(rprec), dimension(:), allocatable :: gcs_w, dz_bottom, dz_top

allocate(gcs_w(nz))
allocate(igen(ngen))
allocate(kbottom(ngen), kbottom_inside(ngen))
allocate(ktop(ngen), ktop_inside(ngen))
allocate(dz_bottom(ngen), dz_top(ngen))


!  Create w-grid (physical grid)
do k=1,nz
  gcs_w(k) = gcs_t(1,1,k)%xyz(3) - dz/2.
enddo

do ng=1,ngen

    !  Assume all trees have same bplane and tplane values for all generations
    bplane = tr_t(1)%gen_t(ng)%bplane
    tplane = tr_t(1)%gen_t(ng)%tplane

  if(bplane < gcs_w(1) .and. tplane < gcs_w(1)) then
    igen(ng) = -1
    kbottom(ng) = -1
    ktop(ng) = -1
    kbottom_inside(ng) = 0
    ktop_inside(ng) = 0
    dz_bottom(ng) = 0.
    dz_top(ng) = 0.
  elseif(bplane > gcs_w(nz) .and. tplane > gcs_w(nz)) then
    igen(ng) = -1
    kbottom(ng) = -1
    ktop(ng) = -1
    kbottom_inside(ng) = 0
    ktop_inside(ng) = 0
    dz_bottom(ng) = 0.
    dz_top(ng) = 0.
  else
    igen(ng) = ng
  !  Perform kbottom, kbottom_inside, ktop, ktop_inside search
    if(bplane < gcs_w(1)) then
      kbottom(ng) = -1
      kbottom_inside(ng) = 0
      dz_bottom(ng) = 0.
    else
      isearch_bottom: do k=2,nz
        if(gcs_w(k) > bplane) then
          kbottom(ng) = k-1
          kbottom_inside(ng) = 1
          dz_bottom(ng) = gcs_w(k) - bplane
          exit isearch_bottom
        endif
      enddo isearch_bottom
    endif
    if(tplane > gcs_w(nz)) then
      ktop(ng) = -1
      ktop_inside(ng) = 0
      dz_top(ng) = 0.
    else
      isearch_top: do k=2,nz
        if(gcs_w(k) >= tplane) then
          ktop(ng) = k-1
          ktop_inside(ng) = 1
          dz_top(ng) = tplane - gcs_w(k-1)
          exit isearch_top
        endif
      enddo isearch_top
    endif
    if(ng == 1) call point_assoc() !  For gen-1 only check point association with the ground
  endif
enddo

!  Open file which to write global data
write (fname,*) 'cylinder_skew_gen_ls.out'
fname = trim(adjustl(fname)) 

if(nproc > 1) then
  write (temp, '(".c",i0)') coord
  fname = trim (fname) // temp
endif

open (unit = 2,file = fname, status='unknown',form='formatted', &
  action='write',position='rewind')
do ng=1,ngen
  write(2,*) igen(ng), kbottom_inside(ng), kbottom(ng), dz_bottom(ng), ktop_inside(ng), ktop(ng), dz_top(ng)
enddo
close(2)

deallocate(gcs_w)
deallocate(igen)
deallocate(kbottom, kbottom_inside)
deallocate(ktop, ktop_inside)
deallocate(dz_bottom, dz_top)

return

end subroutine gen_assoc

!**********************************************************************
subroutine point_assoc()
!**********************************************************************
$if ($MPI)
use param, only : nproc, coord
$endif
implicit none

character(64) :: fname, temp
integer :: i,j,k

!  Open file which to write global data
write (fname,*) 'cylinder_skew_point_ls.out'
fname = trim(adjustl(fname)) 

if(nproc > 1) then
  write (temp, '(".c",i0)') coord
  fname = trim (fname) // temp
endif

open (unit = 2,file = fname, status='unknown',form='formatted', &
  action='write',position='rewind')
do k=1,nz
  do j = 1,ny
    do i = 1,nx+2
      write(2,*) gcs_t(i,j,k)%itype
    enddo
  enddo
enddo
   
close(2)

return
end subroutine point_assoc

end subroutine finalize
!############################################################################################################
