pro cs10int, file, w, sint, mu, cint, plot=plot
;Read output from synthmag code. Specail "cleaning" for Cool Stars 10
;Inputs:
; file (string) name of ".prf" file generated by synthmag
; w (vector(nx)) wavelength scale for output spectrum
; /plot (switch) enables diagnostic plot
;Outputs:
; sint (array(nx,nmu)) intensity spectra for mu values
; mu (vector(nmu)) mu values corresponding to intensities in sint
; cint (vector(2,nmu)) continuum intensities at endpoints of x for mu values
;History:
; 12-Jul-97 Valenti  Adapted from magint.pro.

if n_params() lt 4 then begin
  print, 'syntax: cs10int, file, w, sint, mu [,cint ,/plot]'
  retall
endif

;Get information about external wavelength scale.
  wmin = min(w, max=wmax)
  nw = n_elements(w)
  if w(0) gt w(nw-1) then begin
    message, /info, 'magint: wavelength scale must be increasing'
    return
  endif

;Setup for Cool Stars 10 profile fix.
  osamp = 2
  nbin = osamp * nw - 1
  wbin = w(0) + (w(nw-1) - w(0)) * dindgen(nbin) / (nbin-1)
  hw = 0.5 * (wbin(nbin-1) - wbin(0)) / (nbin-1)

;Open file.
  openr, unit, file, /get_lun

;Skip line list.
  sbuff = ''
  nlin = 0L
  readf, unit, nlin
  for i=1,nlin do readf, unit, sbuff

;Read number of mu values.
  nmu = 0
  readf, unit, nmu

;Initialize arrays.
  sint  = dblarr(nw, nmu)
  mu    = fltarr(nmu)
  cint  = dblarr(2, nmu)

;Loop thru mu angles.
  nx = 0L
  imu = 0
  xmu = 0d0
  cdata = dblarr(4)
  for imu=0, nmu-1 do begin

;Read and store header information.
    readf, unit, imu, xmu
    imu = imu - 1				;switch to zero base
    mu(imu) = xmu				;current mu value
    readf, unit, cdata
    xcint = cdata( [0,2] )			;continuum wavelengths
    ycint = cdata( [1,3] )			;continuum intensities
    cint(*,imu)  = interpol(ycint, xcint, [wmin,wmax])
    readf, unit, nx				;number of wavelength

;Check that model spectra do not extend beyond external wavelength scale.
    if xcint(0) gt wmin or xcint(1) lt wmax then begin
      print, 'magint: external wavelength scale extends beyond model range.'
      print, '        trim to wavelength range [ ' $
           + strtrim(string(xcint(0), form='(f20.4)'), 2) $
           + ', ' + strtrim(string(xcint(1), form='(f20.4)'), 2) $
           + ' ]'
      sint = 0
      free_lun, unit
      return
    endif

;Initialize spectrum variables.
    x = dblarr(nx)
    y = dblarr(nx)

;Read wavelengths and intensities.
    readf, unit, x, y

;Clean up profile (fix for Cool Stars 10).
    xb = replicate(-1.0, nbin)
    yb = replicate(-1.0, nbin)
    for ibin=0, nbin-1 do begin
      iwhr = where(abs(x - wbin(ibin)) le hw, nwhr)
      if nwhr gt 0 then begin
        xb(ibin) = total(x(iwhr)) / nwhr
        yb(ibin) = total(y(iwhr)) / nwhr
      endif
    endfor
    iwhr = where(xb gt 0)
    xb = [wmin, xb(iwhr), wmax]
    yb = [interpol(y, x, wmin), yb(iwhr), interpol(y, x, wmax)]

;Resample onto external wavelength grid.
    secder = spl_init(xb, yb)
    sint(*,imu) = spl_interp(xb, yb, secder, w)

;Read and ignore Stokes Q, U, and V
    readf, unit, y, y, y
  endfor

;Close file.
  free_lun, unit

;Make plot, if requested.
  if keyword_set(plot) then begin
    if w(0) gt 1e4 then fmt='(i5)' else fmt=''
    ymin = min(sint, max=ymax)
    plot, w, sint(*,0), /xsty, yr=[ymin,ymax], /yno, xtickf=fmt
    for imu=1,nmu-1 do oplot, w, sint(*,imu)
  endif

end