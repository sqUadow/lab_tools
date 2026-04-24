macro "manual_gel_label_span_first_last [1]"{
    // --- SETUP ---
    if (isOpen("Log")) { selectWindow("Log"); run("Close"); }
    run("Console");
    print("\\Clear");
    print("--- Script Started (span mode) ---");

    var LADDER_TYPE = "Unknown";

    shift=1; ctrl=2; rightButton=4; alt=8; leftButton=16;

    x2=-1; y2=-1; z2=-1; flags2=-1;
    label_count = 1;
    first_lane_x = -1;
    last_lane_x = -1;
    labelX = -1; labelY = -1;
    roi_name_log = "";
    lane_tick_count = 0;
    title_text = "";

    // --- IMAGE PREP ---
    setBatchMode(false);
    run("Duplicate...", " ");
    run("RGB Color");
    original_image = getTitle();

    getDimensions(width, height, channels, slices, frames);
    border_size = 330;
    title_thresh = border_size * 0.5;

    // --- HORIZONTAL EXTENSION (add margins on left and right) ---
    side_margin = 80;
    new_width = width + (side_margin * 2);

    newImage("extended", "RGB black", new_width, height, 1);
    setColor(50, 50, 50);
    run("Select All");
    run("Fill", "slice");
    run("Select None");
    extended_title = getTitle();

    selectWindow(original_image);
    run("Select All");
    run("Copy");
    selectWindow(extended_title);
    makeRectangle(side_margin, 0, width, height);
    run("Paste");
    run("Select None");
    rename("extended_gel");
    extended_gel_title = getTitle();

    selectWindow(original_image);
    close();

    original_width = width;
    width = new_width;

    // --- TOP BORDER ---
    newImage("border", "RGB black", width, border_size, 1);
    setColor(50, 50, 50);
    run("Select All");
    run("Fill", "slice");
    run("Select None");
    border_title = getTitle();

    run("Combine...", "stack1=[" + border_title + "] stack2=[" + extended_gel_title + "] combine");
    if (nSlices > 1) run("Flatten");

    workingImageID = getImageID();
    final_height = getHeight();

    if (getVersion>="1.37r") setOption("DisablePopupMenu", true);

    setColor("white");
    setFont("SansSerif", 22, "antialiased");
    angle = 45;

    // tick_x_offset and tick_y_offset are computed dynamically in the preview loop
    // as 25% of the lane width, so they scale with the gel.

    // --- INTERACTIVE LOOP ---
    print("Click title area (top) for a title, then click FIRST and LAST lanes.");
    print("NOTE: Image has been extended by " + side_margin + "px on each side.");

    while (true) {
        getCursorLoc(x, y, z, flags);
        wait(20);

        if (x!=x2 || y!=y2 || z!=z2 || flags!=flags2) {
            if ((flags&leftButton)!=0) {
                flags = -1;
                if (y < title_thresh) {
                    inputTitle = getString("Enter Title", "Title");
                    title_text = inputTitle;
                    setFont("SanSerif", 32, "bold");
                    setJustification("center");
                    draw_named_text(inputTitle, "title: " + inputTitle, width/2, 23);
                    Overlay.show;
                }
                else {
                    if (label_count > 1 && abs(x - labelX) < 10) {
                         // Ignore double click
                    } else {
                        if (label_count == 1) {
                            first_lane_x = x;
                            print("First (ladder) lane set at x=" + x);
                        } else {
                            last_lane_x = x;
                            print("Last lane set at x=" + x);
                        }

                        labelX = x;
                        labelY = y;
                        lane_tick_count++;

                        setColor("white");
                        setFont("SansSerif", 22, "antialiased");
                        setJustification("left");
                        if (label_count == 1)
                            draw_named_text_angled("-", "ladder tick", x, border_size, angle);
                        else
                            draw_named_text_angled("-", "last tick", x, border_size, angle);
                        Overlay.show;
                        wait(400);

                        if (label_count == 2) {
                            print("First + last marked. Proceeding...");
                            break;
                        }
                        label_count++;
                    }
                }
            }
            else if ((flags&rightButton)!=0) {
                 removeOverlay(labelX, labelY);
            }
            x2=x; y2=y; z2=z; flags2=flags;
            wait(50);
        }
    }

    if (getVersion>="1.37r") setOption("DisablePopupMenu", false);

    // Ensure first is left of last; swap if needed
    if (last_lane_x < first_lane_x) {
        tmp_x = first_lane_x;
        first_lane_x = last_lane_x;
        last_lane_x = tmp_x;
    }

    // --- INTERACTIVE LANE-COUNT PREVIEW LOOP ---
    // Each OK redraws ticks + faint dashed lane-border guides at the slider's count.
    // Check "Accept" and OK once the tick count matches the gel. If you change the
    // slider and check Accept in the same step, the overlay is redrawn once more
    // with the new value before the loop exits.
    total_lanes = 10;
    preview_accepted = false;

    while (true) {
        Overlay.remove;
        roi_name_log = "";
        lane_tick_count = 0;

        // Title
        if (lengthOf(title_text) > 0) {
            setColor("white");
            setFont("SanSerif", 32, "bold");
            setJustification("center");
            draw_named_text(title_text, "title: " + title_text, width/2, 23);
        }

        // Lane width drives tick offsets: shift left and down by 25% of lane width
        avg_dist_pv = (last_lane_x - first_lane_x) / (total_lanes - 1);
        tick_x_offset = -round(avg_dist_pv * 0.25);
        tick_y_offset = round(avg_dist_pv * 0.25);

        // First tick
        setColor("white");
        setFont("SansSerif", 22, "antialiased");
        setJustification("left");
        lane_tick_count++;
        draw_named_text_angled("-", "ladder tick", first_lane_x + tick_x_offset, border_size + tick_y_offset, angle);

        // Intermediate + last ticks
        for (pv_i = 1; pv_i < total_lanes - 1; pv_i++) {
            lane_x_pv = round(first_lane_x + pv_i * avg_dist_pv);
            lane_tick_count++;
            draw_named_text_angled("-", "tick lane " + (pv_i+1), lane_x_pv + tick_x_offset, border_size + tick_y_offset, angle);
        }
        lane_tick_count++;
        draw_named_text_angled("-", "tick lane " + total_lanes, last_lane_x + tick_x_offset, border_size + tick_y_offset, angle);

        // Faint dashed lane-border guides
        draw_lane_guides(first_lane_x, last_lane_x, total_lanes, border_size + 8, final_height - 4);

        Overlay.show;

        if (preview_accepted) break;

        Dialog.create("Adjust lane count");
        Dialog.addMessage("Drag slider and click OK to preview.\nCheck 'Accept' when the tick count matches the gel.");
        Dialog.addSlider("Total lanes", 2, 40, total_lanes);
        Dialog.addCheckbox("Accept", false);
        Dialog.show();
        total_lanes = Dialog.getNumber();
        if (total_lanes < 2) total_lanes = 2;
        preview_accepted = Dialog.getCheckbox();
    }

    avg_dist = (last_lane_x - first_lane_x) / (total_lanes - 1);

    // --- DYNAMIC WIDTH CALCULATION ---
    scan_width = round(avg_dist / 3);
    if (scan_width < 4) scan_width = 4;
    if (scan_width > 50) scan_width = 50;

    print("Total lanes: " + total_lanes);
    print("Calculated Lane Separation: " + avg_dist + "px");
    print("Dynamic Scan Width: " + scan_width + "px");

    // --- EXECUTE ---
    selectImage(workingImageID);

    // 1. ANALYZE LADDER (Lane 1)
    ladder_data = analyze_ladder(first_lane_x, final_height, border_size, workingImageID, false, scan_width);

    if (lengthOf(ladder_data) > 0) {
        parts = split(ladder_data, "|");
        ladder_y_str = parts[0];
        ladder_sizes_str = parts[1];

        // 2. ANALYZE SAMPLE LANES (2 .. total_lanes). Ticks were drawn in the preview loop.
        for (i=1; i < total_lanes; i++) {
            lane_x = round(first_lane_x + i * avg_dist);
            analyze_single_sample(lane_x, final_height, border_size, workingImageID, ladder_y_str, ladder_sizes_str, scan_width);
        }
    } else {
        print("Skipping band analysis. Edit labels manually via the ROI Manager.");
        // Ticks and guides already drawn in preview loop; nothing to add here.
    }

    // Add Date (runs for both normal analysis and Skip Ladder)
    MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    TimeString = "" + dayOfMonth + "-" + MonthNames[month] + "-" + year;
    if (dayOfMonth<10) TimeString = "0" + TimeString;
    setFont("SanSerif", 32, "bold");
    setJustification("center");
    setColor("white");
    draw_named_text(TimeString, "date: " + TimeString, width/2, 35);
    Overlay.show;

    selectImage(workingImageID);
    run("Select None");
    run("Line Width...", "line=1");
    run("To ROI Manager");
    rename_text_rois_in_manager();
    roiManager("Show All without labels");
    selectWindow("ROI Manager");
    print("Done.");


    // ================= FUNCTIONS =================

    function draw_lane_guides(first_x, last_x, total, top_y, bottom_y) {
        if (total < 2) return;
        avg = (last_x - first_x) / (total - 1);
        setColor(120, 120, 120);
        setLineWidth(1);
        dash_on = 8;
        dash_off = 6;
        // total+1 borders: one to the left of the first lane, one to the right of the last, and between each pair
        for (gi = 0; gi <= total; gi++) {
            bx = round(first_x - avg/2 + gi * avg);
            yc = top_y;
            while (yc < bottom_y) {
                seg_end = yc + dash_on;
                if (seg_end > bottom_y) seg_end = bottom_y;
                Overlay.drawLine(bx, yc, bx, seg_end);
                append_roi_name("guide");
                yc = seg_end + dash_off;
            }
        }
        setColor("white");
    }

    function analyze_single_sample(x_pos, im_height, top_margin, imgID, ladder_y_str, ladder_sizes_str, scan_width) {
        line_start_y = top_margin + 50;
        line_end_y = im_height - 10;

        selectImage(imgID);
        run("Duplicate...", "title=temp_sample");
        run("8-bit");
        tempID = getImageID();

        run("Subtract Background...", "rolling=50");
        run("Gaussian Blur...", "sigma=2");

        run("Select None");
        run("Line Width...", "line=" + scan_width);
        makeLine(x_pos, line_start_y, x_pos, line_end_y);

        profile = getProfile();
        selectImage(tempID);
        close();

        if (profile.length == 0) return;

        Array.getStatistics(profile, min, max, mean, stdDev);

        tol = (max - min) * 0.05;
        if (tol < 10) tol = 10;

        peaks = Array.findMaxima(profile, tol);

        print("Lane x=" + x_pos + ": Found " + peaks.length + " peaks.");

        selectImage(imgID);
        setFont("SansSerif", 12, "antialiased");
        setJustification("left");
        setColor("yellow");

        label_x_offset = 0;
        label_y_offset = -12;

        for (i=0; i<peaks.length; i++) {
            y_pixel = peaks[i] + line_start_y;
            size_bp = calculate_bp(peaks[i], ladder_y_str, ladder_sizes_str);

            if (size_bp > 0) {
                label_draw_x = x_pos + label_x_offset;
                label_draw_y = y_pixel + label_y_offset;
                draw_named_text("" + size_bp, "" + size_bp, label_draw_x, label_draw_y);
            }
        }
        Overlay.show;
    }

    function calculate_bp(y_rel_pos, ladder_y_str, ladder_sizes_str) {
        if (lengthOf(ladder_y_str) == 0) return 0;

        ladder_y_arr = split(ladder_y_str, ",");
        ladder_size_arr = split(ladder_sizes_str, ",");
        num_ladder = ladder_y_arr.length;

        if (num_ladder < 2) return 0;

        upper_idx = -1;
        lower_idx = -1;

        min_y = parseFloat(ladder_y_arr[0]);
        max_y = parseFloat(ladder_y_arr[num_ladder-1]);

        if (y_rel_pos < min_y) {
            upper_idx = 0;
            lower_idx = 1;
        }
        else if (y_rel_pos > max_y) {
            upper_idx = num_ladder - 2;
            lower_idx = num_ladder - 1;
        }
        else {
            for (k=0; k<num_ladder; k++) {
                curr_y = parseFloat(ladder_y_arr[k]);
                if (curr_y > y_rel_pos) {
                    lower_idx = k;
                    upper_idx = k - 1;
                    break;
                }
            }
        }

        if (upper_idx < 0 || lower_idx < 0) return 0;

        y1 = parseFloat(ladder_y_arr[upper_idx]);
        y2 = parseFloat(ladder_y_arr[lower_idx]);

        s1_str = ladder_size_arr[upper_idx];
        s2_str = ladder_size_arr[lower_idx];

        s1 = parse_size(s1_str);
        s2 = parse_size(s2_str);

        if (s1 == 0 || s2 == 0) return 0;

        log_s1 = log(s1) / log(10);
        log_s2 = log(s2) / log(10);

        if (y2 == y1) return 0;

        frac = (y_rel_pos - y1) / (y2 - y1);

        log_size = log_s1 + frac * (log_s2 - log_s1);
        calc_size = pow(10, log_size);

        rounding_step = 50;

        if (LADDER_TYPE == "1kb+") {
            rounding_step = 100;
        } else if (LADDER_TYPE == "GeneRuler 1kb") {
            rounding_step = 50;
        } else if (LADDER_TYPE == "Ultra Low") {
            rounding_step = 5;
        }

        if (calc_size < 500 && LADDER_TYPE != "Ultra Low") {
            rounding_step = 5;
        }

        final_size = round(calc_size / rounding_step) * rounding_step;

        if (final_size > 20000) return 0;

        return final_size;
    }

    function parse_size(size_str) {
        multiplier = 1;
        size_str = replace(size_str, " ", "");
        if (endsWith(size_str, "k")) {
            multiplier = 1000;
            size_str = replace(size_str, "k", "");
        }
        val = parseFloat(size_str);
        return val * multiplier;
    }

    // --- LADDER ANALYSIS ---
    function analyze_ladder(x_pos, im_height, top_margin, imgID, silent_mode, scan_width) {
        if (silent_mode) return "";

        print("--- Analyzing Ladder Standard ---");

        Dialog.create("Choose Ladder");
        Dialog.addMessage("Select the specific ladder used for this gel:");
        Dialog.addChoice("Type:", newArray("Skip Ladder", "GeneRuler 1kb", "1kb Plus", "Express", "Ultra Low"), "Skip Ladder");
        Dialog.show();
        user_choice = Dialog.getChoice();

        if (user_choice == "Skip Ladder") {
            LADDER_TYPE = "Skipped";
            print("Skip Ladder selected. No band labels will be drawn.");
            return "";
        }

        line_start_y = top_margin + 50;
        line_end_y = im_height - 10;

        selectImage(imgID);
        run("Duplicate...", "title=temp_ladder");
        run("8-bit");
        tempID = getImageID();

        run("Subtract Background...", "rolling=50");
        run("Gaussian Blur...", "sigma=2");

        run("Select None");
        run("Line Width...", "line=" + scan_width);
        makeLine(x_pos, line_start_y, x_pos, line_end_y);
        profile = getProfile();
        selectImage(tempID); close();

        if (profile.length == 0) return "";

        Array.getStatistics(profile, min, max, mean, stdDev);

        tol_high = (max - min) * 0.10;
        if (tol_high < 10) tol_high = 10;
        peaks_high = Array.findMaxima(profile, tol_high);

        final_peaks = Array.copy(peaks_high);
        Array.sort(final_peaks);
        final_num = final_peaks.length;

        labels = newArray(0);
        ref_idx = 0;

        max_p_val = -1;
        brightest_p_idx = -1;
        for (i=0; i<final_num; i++) {
             val = profile[final_peaks[i]];
             if (val > max_p_val) {
                 max_p_val = val;
                 brightest_p_idx = i;
             }
        }

        if (user_choice == "GeneRuler 1kb") {
            LADDER_TYPE = "GeneRuler 1kb";
            labels = newArray("10k", "8k", "6k", "5k", "4k", "3500", "3k", "2500", "2000", "1500", "1000", "750", "500", "250");
            ref_idx = 2;
        }
        else if (user_choice == "1kb Plus") {
            LADDER_TYPE = "1kb+";
            labels = newArray("20k", "10k", "7k", "5k", "4k", "3k", "2k", "1.5k", "1k", "850", "650", "500", "400", "300", "200", "100");
            ref_idx = 3;
        }
        else if (user_choice == "Express") {
            LADDER_TYPE = "Express";
            labels = newArray("5000", "3000", "2000", "1500", "1000", "750", "500", "300", "100");
            ref_idx = 6;
        }
        else if (user_choice == "Ultra Low") {
            LADDER_TYPE = "Ultra Low";
            labels = newArray("700", "650", "400", "300", "200", "150", "100", "75", "50", "35", "25", "15", "10");
            ref_idx = 3;
        }

        print("Selected: " + LADDER_TYPE);

        new_upper_idx = brightest_p_idx;

        selectImage(imgID);
        setFont("SansSerif", 16, "antialiased");
        setJustification("right");
        setColor("white");

        str_y = "";
        str_s = "";

        for (i=0; i<final_num; i++) {
            offset = i - new_upper_idx;
            label_idx = ref_idx + offset;

            if (label_idx >= 0 && label_idx < labels.length) {
                txt = labels[label_idx];
                y_loc = final_peaks[i] + line_start_y;

                label_draw_x = x_pos - 20;
                draw_named_text(txt, txt, label_draw_x, y_loc + 6);

                if (lengthOf(str_y) > 0) {
                    str_y = str_y + ",";
                    str_s = str_s + ",";
                }
                str_y = str_y + final_peaks[i];
                str_s = str_s + txt;
            }
        }
        Overlay.show;

        return str_y + "|" + str_s;
    }

    function draw_named_text(txt, roi_name, x_pos, y_pos) {
        Overlay.drawString(txt, x_pos, y_pos);
        append_roi_name(roi_name);
    }

    function draw_named_text_angled(txt, roi_name, x_pos, y_pos, angle_value) {
        Overlay.drawString(txt, x_pos, y_pos, angle_value);
        append_roi_name(roi_name);
    }

    function append_roi_name(roi_name) {
        if (lengthOf(roi_name_log) > 0)
            roi_name_log = roi_name_log + "\n";
        roi_name_log = roi_name_log + roi_name;
    }

    function rename_text_rois_in_manager() {
        if (lengthOf(roi_name_log) == 0) return;

        roi_names = split(roi_name_log, "\n");
        roi_count = roiManager("count");
        rename_count = roi_names.length;
        if (roi_count < rename_count) rename_count = roi_count;

        for (i=0; i<rename_count; i++) {
            roiManager("Select", i);
            roiManager("Rename", roi_names[i]);
        }
    }
}
