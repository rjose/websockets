function check_estimate(field, value, row)
{
        # Blanks are OK
        if (value == "")
                return;

        # Estimates have to be valid
        if (value !~ /^[1-9]*[SMLQ]$/)
                bad_estimates[sprintf("%d: '%s', '%s'", row, field, value)] = 1
}

# TODO: Add check on mobile track

BEGIN   { FS = "\t" }

NR > 1  {
                check_estimate("Native", $10, NR)
                check_estimate("Web", $11, NR)
                check_estimate("Apps", $12, NR)

                tracks[$4] = 1
        }

END     {
                # Print bad estimates
                if (length(bad_estimates) > 0) {
                        print("")
                        print("Invalid estimate strings")
                        print("========================")
                        for (error in bad_estimates) {
                                print(error)
                        }
                }

                # Check tracks that should be merged
                for (track in tracks) {
                        split(track, track_arr, " ")
                        
                        for (other_track in tracks) {
                                compared_tracks[track other_track] = 1

                                if (track != other_track &&
                                    compared_tracks[other_track track] != 1 &&
                                    index(other_track, track_arr[1]) == 1) {
                                        key = sprintf("Merge tracks? '%s' and '%s'",
                                                             track, other_track)
                                        merge_tracks[key] = 1
                                    }
                        }
                }

                if (length(merge_tracks) > 0) {
                        print("")
                        print("Merge Tracks?")
                        print("=============")
                        for (warning in merge_tracks) {
                                print(warning)
                        }

                }
        }


