#' Calculate the pressure/strain response spectrum for given formation properties
#'
#' calculate Kitagawa equation 17
#'
#' @name well_response
#' @export
#' 
#' @param omega  frequency,  (see freq.units)
#' @param T.     effective aquifer transmissivity \eqn{[m^2/s]}
#' @param S.     well storativity,  \eqn{[]}
#' @param Vw.    well volume,	 \eqn{[m^3]}
#' @param Rs.    radius of screened portion,  \eqn{[m]}
#' @param Ku.    undrained bulk modulus,  \eqn{[Pa]}
#' @param B.     Skempton's coefficient,  \eqn{[]}
#' @param Avs.   amplification factor for volumetric strain \eqn{E_{kk,obs}/E_{kk}},  \eqn{[]}
#' @param Aw.    amplification factor of well volume change for \eqn{E_{kk}},  \eqn{[]}
#' @param rho.   fluid density \eqn{[kg/m^3]}
#' @param Kf.    bulk modulus of fluid,  \eqn{[Pa]}
#' @param grav.  local gravitational acceleration \eqn{[m/s^2]}
#' @param freq.units  set what the units of frequency (omega) are: "rad_per_sec" (default, NULL), or "Hz"
#'
#' @return Matrix with three columns: \eqn{\omega}, \eqn{A_\alpha (\omega)}, \eqn{\Phi_\alpha (\omega)}
#' where the units of \eqn{\omega} will be radians per second
#' 
#' @author Andrew Barbour <andy.barbour@@gmail.com>
#' 
#' @references Kitagawa, Y., S. Itaba, N. Matsumoto, and N. Koisumi (2011),
#' Frequency characteristics of the response of water pressure in a closed well to volumetric strain in the high-frequency domain,
#' \emph{J. Geophys. Res.}, \strong{116}, B08301, doi:10.1029/2010JB007794.
#' 
#' @references \url{http://www.agu.org/pubs/crossref/2011/2010JB007794.shtml}
#'
#' @seealso \code{\link{sensing_volume}}, \code{\link{kitplot}}
#' 
#' @examples
#' #### dummy example
#' well_response(1:10, T.=1, S.=1, Vw.=1, Rs.=1, Ku.=1, B.=1)
#' 
#' #### a more physically realistic calculation:
#' # Physical params applicable for B084 borehole
#' # (see: http://pbo.unavco.org/station/overview/B084/ for details)
#' #
#' Rc <- 0.0508   # m, radius of water-sensing (2in)
#' Lc <- 146.9    # m, length of grouted region (482ft)
#' Rs <- 3*Rc     # m, radius of screened region (6in)
#' Ls <- 9.14     # m, length of screened region (30ft)
#' #
#' # calculate the sensing volume for the given well parameters
#' Volw <- sensing_volume(Rc, Lc, Rs, Ls) # m**3, ~= 1.8
#' #
#' Frqs <- 10**seq.int(from=-4,to=0,by=0.1) # log10-space
#' head(Rsp <- well_response(omega=Frqs, T.=1e-6, S.=1e-5, 
#' Vw.=Volw, Rs.=Rs, Ku.=40e9, B.=0.2, freq.units="Hz"))
#' #
#' kitplot(Rsp)
#'
well_response <-
function(omega,
         T., S., Vw., Rs., Ku., B.,
         Avs.=1,
         Aw.=1,
         rho.=1000, 
         Kf.=2.2e9,
         grav.=9.81,
         freq.units=NULL) UseMethod("well_response")

# @return \code{NULL}
#' @rdname well_response
#' @docType methods
#' @method well_response default
#' @S3method well_response default
well_response.default <-
  function(omega,
           T., S., Vw., Rs., Ku., B.,
           Avs.=1,
           Aw.=1,
           rho.=1000, 
           Kf.=2.2e9,
           grav.=9.81,
           freq.units=NULL){
    #
    # Enforce units of omega to be radians/sec
    fc <- switch(match.arg(freq.units, c("rad_per_sec","Hz")),
                 rad_per_sec=1,
                 Hz=2*pi
    )
    omega <- fc*omega
    #
    # Alpha function
    Alpha. <- omega_constants(omega, c.type="alpha", S.=S., T.=T., Rs.=Rs.)
    # A1, and A2 (functions of Phi and Psi, calculated internally)
    Amat <- alpha_constants(Alpha., c.type="A")
    stopifnot(ncol(Amat)==7)
    rm(Alpha.)  # cleanup
    #  A1,2 are in Mod(A.[,6:7]) 
    A12 <- matrix(Mod(Amat[,6:7]),ncol=2)  # is complex, but imag is zero, so == abs
    stopifnot(ncol(A12)==2)
    rm(Amat)    # cleanup
    A1 <- A12[,1]
    A2 <- A12[,2]
    rm(A12)     # cleanup
    #
    # prevent duplicate calculations
    rhog <- rho. * grav.
    #print(summary(omega))
    TVFRG <- 2 * pi * T. / omega / Vw. / rhog
    #
    # calculate amp and phase of response
    #
    tmpd. <- Ku. * B. / Aw. * TVFRG - A2
    rNum. <- tmpd. * tmpd. + A1 * A1
    rm(tmpd.)
    tmpd. <- Kf. * TVFRG  -  A2
    rDen. <- tmpd. * tmpd. + A1 * A1
    rm(tmpd.)
    ##
    ## amplitude, Kitagawa equation 20
    ##
    Amp. <- Kf. * Aw. / Avs. / rhog * sqrt(rNum. / rDen.)
    ##
    ## phase, Kitagawa equation 21
    ##
    Y. <- (Kf. - Ku. * B. / Aw.) * TVFRG * A1
    X. <- (Ku. * B. / Aw. * TVFRG - A2) * (Kf. * TVFRG - A2) + A1 * A1
    Phs. <- atan2(-1*Y.,-1*X.)
    #
    # params?
    # attributes?
    # message?
    #
    # return results
    toret <- cbind(omega, Amp., Phs.)
    return(toret)
  }