module times
  use kinds, only : wp
  use constants, only : pi, deg
  implicit none
  !
  real(wp), parameter :: fajr_angle = 17.833_wp*deg
  real(wp), parameter :: ishaa_angle = 17.14_wp*deg
  real(wp), parameter :: sunrise_angle = 0.68_wp*deg
  real(wp), parameter :: sunset_angle = 1.53_wp*deg
  !
  real(wp), protected :: dec      ! Sun's Declination
  integer, protected :: mid_day   ! Midday time
  integer, protected :: eq_time   ! Equation of time
  logical, protected :: initiated = .false.
  ! Prayer times + astronomical sunrise
  type prayers
    integer :: Fajr, Sunrise, Dhuhur, Asr, Maghrib, Ishaa
  end type prayers
  ! Extra times ( Sunrise, Sunset, Fajr_correct, Ishaa_correct )
  type extra_times
    integer :: sunrise, sunset, fajr_correct, ishaa_correct
  end type
contains

  subroutine prayer_times(latitude,times)
    real(wp), intent(in) :: latitude
    type(prayers), intent(out) :: times
    !
    real(wp) :: theta
    !
    ! Check if the common variables was calculated
    if( .not. initiated ) error stop "You should call init(...) before"
    ! Fajr
    times%Fajr = mid_day - time_angle(latitude,fajr_angle)
    ! Astronomical sunrise
    times%Sunrise = mid_day - time_angle(latitude,sunrise_angle)
    ! Dhuhur
    times%Dhuhur = mid_day + 30
    ! Asr
    theta = atan( 1._wp/( 1._wp + tan(latitude-dec) ) )
    times%Asr = mid_day + time_angle(latitude,-theta) + 30
    ! Maghrib
    times%Maghrib = mid_day + time_angle(latitude,sunset_angle)
    ! Ishaa
    times%Ishaa = mid_day + time_angle(latitude,ishaa_angle)
    !
  end subroutine prayer_times

  ! Calculate the sunrise and sunset times plus the fajr and ishaa
  subroutine other_times(latitude,times,h)
    real(wp), intent(in) :: latitude, h(:)
    type(extra_times), intent(out) :: times
    !
    real(wp) :: hra
    integer :: i, j
    !
    ! Sunrise
    hra = -15*time_angle(latitude,sunrise_angle)/3600._wp
    do i = 0, 300
      hra = hra + i*0.02_wp
      j = int( azimuth(latitude,hra*deg)/(2._wp*pi) * size(h) )
      if( h(j)-sunrise_angle<=elevation(latitude,hra*deg) ) exit
    end do
    times%sunrise = mid_day - time_angle( latitude, sunrise_angle-h(j) )
    ! Fajr
    times%fajr_correct = mid_day - time_angle(latitude,fajr_angle-h(j))
    ! Sunset
    hra = 15*time_angle(latitude,sunset_angle)/3600._wp
    do i = 0, 300
      hra = hra - i*0.02_wp
      j = int( (2._wp*pi-azimuth(latitude,hra*deg))/(2._wp*pi) * size(h) )
      if( h(j)-sunset_angle<=elevation(latitude,hra*deg) ) exit
    end do
    times%sunset = mid_day + time_angle( latitude, sunset_angle-h(j) )
    ! ishaa_corret
    times%ishaa_correct = mid_day + time_angle(latitude,ishaa_angle-h(j))
    !
  end subroutine other_times

  ! Calculate the Elevation angle of the sun
  real(wp) function elevation(latitude,angle)
    real(wp), intent(in) :: latitude, angle
    !
    elevation = asin( sin(dec)*sin(latitude)+cos(dec)*cos(latitude)*cos(angle) )
    !
  end function elevation

  ! Calculate the azimuth angle of the sun
  real(wp) function azimuth(latitude,angle)
    real(wp), intent(in) :: latitude, angle
    !
    azimuth = acos( (sin(dec)*cos(latitude)-cos(dec)*sin(latitude)*cos(angle)) &
      /cos( elevation(latitude,angle) ) )
    !
  end function azimuth

  ! Calculate the time (relative to Midday) corresponding to sun's angle
  ! (relative to the horizon)
  integer function time_angle(latitude,theta)
    real(wp), intent(in) :: latitude, theta
    time_angle = acos( ( -sin(theta)-sin(latitude)*sin(dec) ) &
      /( cos(latitude)*cos(dec) ) )/deg*240
  end function time_angle

  ! Calculate the common variables : Equation of time, Declination, Midday
  subroutine init(time_zone,longitude,day)
    use time_date, only : dat, julian_day
    integer, intent(in) :: time_zone
    real(wp), intent(in) :: longitude
    type(dat), intent(in) :: day
    !
    integer :: n ! Number of days since 01/01/2000
    real(wp) :: l, g, lambda, eps, alpha
    !
    n = julian_day(day) - 2451545
    l = mod( 280.459_wp+0.98564736_wp*n, 360._wp )*deg
    g = mod( 357.529_wp+0.98560028_wp*n, 360._wp )*deg
    lambda =  l + ( 1.915_wp*sin(g)+0.02_wp*sin(2*g) )*deg
    eps = ( 23.439_wp+3.6e-7_wp*n )*deg
    alpha = atan2( cos(eps)*sin(lambda), cos(lambda) )
    !
    dec = asin( sin(eps)*sin(lambda) )
    eq_time = ( (l-alpha)/deg - 180*nint((l-alpha)/deg/180) )*240
    mid_day = 12*3600 + ( time_zone*15 - longitude/deg )*240 - eq_time
    initiated = .true.
    !
  end subroutine init

end module times
