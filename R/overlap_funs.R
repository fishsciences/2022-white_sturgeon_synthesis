chk_overlaps = function(df) {
  
  if(length(unique(df$Location_name)) == 1) return(FALSE) # if the receiver doesn't have more than 1 location, don't continue further in the function
  any(as.Date(df$Start[-1]) < as.Date(df$End[-nrow(df)])) # gets rid of first start value and last end value so that the rows line up, and then checks if any receiver has a start date that occurs before its previous end date
  
}

# internal function that compares two locations of a single receiver:

return_overlaps = function(z) { 
  
  if(length(z) != 2) stop("locations != 2")
    
    x = z[[1]]
    y = z[[2]]
    setkey(y, Start, End)
    
    res = data.table::foverlaps(x,
                                y,
                                type = "within",
                                which = TRUE,
                                nomatch = NULL)
    if(nrow(res)) { # if the resulting data.table has rows, then
    ans = list() # initialize a list and populate
    for(i in seq(nrow(res))) {

      ans[[i]] = as.data.frame(rbind(x[res$xid[i], ],
                                     y[res$yid[i], ]))
        

    }
    ans = do.call(rbind, ans)
    } else {
      
        ans = x[0,]
 
    } # if the resulting data.table has no rows, return empty df for that rec

    
    
    return(ans) # otherwise return the ans list made in step 1
    
  }
  
# wrapper function; takes a data.frame of all a receiver's deployments

feeder = function(rec_df, split_col = "Location_name") {

  z = lapply(split(rec_df, rec_df[[split_col]]), setDT)

  if(length(z) < 2 ) return(FALSE) # if there is only 1 location, can't run foverlaps

  if(length(z) == 2) ans = return_overlaps(z) # if there's 2 locs, can just run the fxn

  if(length(z) > 2) { # if there's more, we need to do some pairwise comps
 
  # create a matrix/array of pairwise indices
  idx = combn(length(z), 2, simplify = FALSE)
  ans = lapply(idx, function(i) return_overlaps(z[i]))

      ans = as.data.frame(rbindlist(ans, fill = TRUE))
      #ans = ans[!sapply(ans, is.null)] # only include the non-nulls
 # if(length(ans) == 0) ans = NULL # if all nulls, becomes list(); change that to a NULL for consistency with the rest
  }
  
  return(ans)
  
}

get_overlaps = function(df,
                        start_col = "Start",
                        end_col = "End")
{
  tt = data.frame(datetime = c(df[[start_col]], df[[end_col]]),
                  action = factor(rep(2:1, each = nrow(df)), labels = c("End", "Start")), # for tie splitting
                  row_id = rep(seq(nrow(df)), times = 2))
  
  tt$tmp = -1
  tt$tmp[tt$action == "Start"] = 1
  
  tt = tt[order(tt$datetime, tt$action),]
  tt$rr = cumsum(tt$tmp)
  ends = which(tt$rr == 0)
  starts = c(1, ends[-length(ends)] + 1)
  ans = mapply(function(a,b) tt[a:b,], starts, ends, SIMPLIFY = FALSE)
  ans = ans[sapply(ans, nrow) > 2]

  lapply(ans, function(a) {
    a[c("rr", "tmp")] = NULL
    cbind(a, df[a$row_id, !colnames(df) %in% c(start_col, end_col)])
    })

}

