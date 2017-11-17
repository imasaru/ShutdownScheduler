/*
    * Copyright (c) 2011-2017 Your Organization (https://yourwebsite.com)
    *
    * This program is free software; you can redistribute it and/or
    * modify it under the terms of the GNU General Public
    * License as published by the Free Software Foundation; either
    * version 2 of the License, or (at your option) any later version.
    *
    * This program is distributed in the hope that it will be useful,
    * but WITHOUT ANY WARRANTY; without even the implied warranty of
    * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    * General Public License for more details.
    *
    * You should have received a copy of the GNU General Public
    * License along with this program; if not, write to the
    * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    * Boston, MA 02110-1301 USA
    *
    * Authored by: Eduard Berloso Clarà <eduard.bc.95@gmail.com>
    */


    public class ShutdownScheduler : Gtk.Application {

        public bool shutdown_programed = false;
        Gtk.Box main_box;
        Gtk.Label remaining_time_lbl;
        DateTime start_time;
        Unity.LauncherEntry launcher;
        Granite.Widgets.DatePicker date;
        Granite.Widgets.TimePicker time;

        public ShutdownScheduler () {
            Object (application_id: "com.github.bcedu.shutdownscheduler",
            flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate () {
            Gtk.ApplicationWindow app_window = new Gtk.ApplicationWindow (this);
            app_window.title = "Shutdown Scheduler";
            app_window.window_position = Gtk.WindowPosition.CENTER;

            // Load CSS
            string css_file = Constants.PKGDATADIR + "/css/main.css";
            var provider = new Gtk.CssProvider();
            try {
                provider.load_from_path(css_file);
                Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
            }

            // Create interface
            Gtk.Box aux_box;
            if (is_shutdown_programed()) {
                aux_box = get_shutdown_info();
            }else {
                aux_box = get_shutdown_programer();
            }
            this.main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            this.main_box.pack_start (aux_box, false, false, 10);
            this.launcher = Unity.LauncherEntry.get_for_desktop_id ("com.github.bcedu.shutdownscheduler.desktop");

            app_window.delete_event.connect (() => {
                if (this.is_shutdown_programed()) return app_window.hide_on_delete ();
                else return false;
            });

            app_window.add(main_box);
            app_window.set_resizable(false);

            var header_bar = new Gtk.HeaderBar ();
            header_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            header_bar.show_close_button = true;
            app_window.set_titlebar (header_bar);

            app_window.show_all ();
            app_window.show ();
        }

        public static int main (string[] args) {
            var app = new ShutdownScheduler ();
            return app.run (args);
        }

        private bool is_shutdown_programed() {
            // Returns True if there is any shutdown programed in the system
            return this.shutdown_programed;
        }

        private Gtk.Box get_shutdown_info() {
            // Returns a Gtk.Box with info about programed shutdown
            Gtk.Box box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            box.get_style_context().add_class ("boxinfo");
            box.pack_start (new Gtk.Label (get_schedule_description()), false, false, 10);
            this.remaining_time_lbl = new Gtk.Label (get_schedule_remaining_time());
            this.remaining_time_lbl.get_style_context().add_class ("timelabel");
            box.pack_start (this.remaining_time_lbl, false, false, 10);
            box.pack_start (get_schedule_cancel_button(), false, false, 10);
            // Start time function to update counter each second
            GLib.Timeout.add_seconds (1, update_counter);
            return box;
        }

        private string get_schedule_description() {
            // Returns a string with the discription of the scheduled shutdown. Example:
            // "Shutdown scheduled for HH:MM:SS DD/MM/YYYY"
            DateTime obj = get_widgets_time();
            return "Shutdown scheduled for " + obj.format("%H:%M:%S %d/%m/%y");
        }

        private string get_schedule_remaining_time() {
            // Returns a string with the remaining time of the scheduled shutdown. Example:
            // "HH:MM:SS"
            DateTime obj = get_widgets_time();
            DateTime now = new DateTime.now_local ();
            TimeSpan diff = obj.difference(now);
            int seconds = (int)(diff/1000000);
            int rem_sec = seconds % 60;
            int minutes = seconds / 60;
            int rem_min = minutes % 60;
            int hours = minutes / 60;
            string aux1 = rem_min.to_string();
            if (rem_min < 10) aux1 = "0"+aux1;
            string aux2 = rem_sec.to_string();
            if (rem_sec < 10) aux2 = "0"+aux2;
            return hours.to_string()+":"+aux1+":"+aux2;
        }

        private double get_percentage_progres() {
            // Returns an int between 0 and 1 representing the percentage of time
            // that has passed since the shutdown was programed to the shutdown time
            DateTime obj = get_widgets_time();
            DateTime now = new DateTime.now_local ();
            TimeSpan passed = now.difference(this.start_time);
            TimeSpan total = obj.difference(this.start_time);
            return (double)passed/(double)total;
        }

        private Gtk.Button get_schedule_cancel_button() {
            // Returns a Gtk.Button to cancel the scheduled shutdown.
            Gtk.Button bt;

            bt = new Gtk.Button.with_label ("Cancel");
            bt.clicked.connect (() => {
                string command = "shutdown -c";
                Posix.system(command);
                this.shutdown_programed = false;
                this.launcher.progress_visible = false;
                update_interface();
            });
            return bt;
        }

        private Gtk.Box get_shutdown_programer() {
            // Returns a Gtk.Box with controls to schedule a shutdown
            Gtk.Box box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            box.get_style_context().add_class ("boxprogramer");
            box.pack_start (get_time_box(), false, false, 10);
            box.pack_start (get_time_buttons_box(), false, false, 10);
            box.pack_start (get_schedule_program_button(), false, false, 10);
            return box;
        }

        private Gtk.Box get_time_box() {
            // Returns a Gtk.Box with interface to enter time to program shutdown
            Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            this.date = new Granite.Widgets.DatePicker();
            this.time = new Granite.Widgets.TimePicker();
            this.date.get_style_context().add_class ("timewidget1");
            this.time.get_style_context().add_class ("timewidget2");

            box.pack_start (this.date, false, false, 10);
            box.pack_start (this.time, false, false, 10);
            return box;
        }

        private Gtk.Box get_time_buttons_box() {
            // Returns a Gtk.Box with buttons to summ/substract time to programed
            // shutdown
            Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            Gtk.Button bt;

            bt = new Gtk.Button.with_label ("+15 min.");
            bt.get_style_context().add_class ("timebutton");
            bt.clicked.connect (() => {add_time(15);});
            box.pack_start (bt, false, false, 10);

            bt = new Gtk.Button.with_label ("+30 min.");
            bt.get_style_context().add_class ("timebutton");
            bt.clicked.connect (() => {add_time(30);});
            box.pack_start (bt, false, false, 10);

            bt = new Gtk.Button.with_label ("+1 h.");
            bt.get_style_context().add_class ("timebutton");
            bt.clicked.connect (() => {add_time(60);});
            box.pack_start (bt, false, false, 10);

            bt = new Gtk.Button.with_label ("+2 h.");
            bt.get_style_context().add_class ("timebutton");
            bt.clicked.connect (() => {add_time(120);});
            box.pack_start (bt, false, false, 10);

            return box;
        }

        private void add_time(int min) {
          // Adds 'min' minutes to thtime that will be scheduled
          DateTime obj = get_widgets_time();
          // Sum 'min' minutes
          obj = obj.add_minutes(min);
          // Store new time to widgets
          this.date.date = obj;
          this.time.time = obj;
        }

        private Gtk.Button get_schedule_program_button() {
            // Returns a Gtk.Button to program shutdown
            Gtk.Button bt = new Gtk.Button.with_label ("Schedule");
            bt.clicked.connect (() => {
                string command = "shutdown +" + get_minutes_to_shutdown();
                Posix.system(command);
                this.shutdown_programed = true;
                this.start_time = new DateTime.now_local ();
                this.launcher.progress_visible = true;
                update_interface();
            });
            return bt;
        }

        private string get_minutes_to_shutdown() {
            // Returns a string with the number of minutes left for when we
            // want to program the shutdown
            DateTime obj = get_widgets_time();
            // Get current local time
            DateTime now = new DateTime.now_local ();
            // Calc. diff. in minutes
            TimeSpan diff = obj.difference(now);
            return (((int)(diff/60000000))+1).to_string();
        }

        private DateTime get_widgets_time() {
          int year, month, day, hour, minute;
          this.date.date.get_ymd(out year, out month, out day);
          hour = this.time.time.get_hour();
          minute = this.time.time.get_minute();
          // Build new DateTime with the data
          return new DateTime.local (year, month, day, hour, minute, 0);
        }

        private void update_interface() {
            // Updates interface depending on programed shutdown
            Gtk.Box aux_box;
            if (is_shutdown_programed()) {
                aux_box = get_shutdown_info();
            }else {
                aux_box = get_shutdown_programer();
            }
            this.main_box.forall ((element) => this.main_box.remove (element));
            this.main_box.pack_start (aux_box, false, false, 10);
            this.main_box.show_all();
        }

        private bool update_counter() {
            this.remaining_time_lbl.set_text(get_schedule_remaining_time());
            if (this.get_schedule_remaining_time().split(":")[2] == "10" && this.get_schedule_remaining_time().split(":")[1] == "00") {
                this.remaining_time_lbl.get_style_context().add_class ("redtimelabel");
            }

            if (this.get_schedule_remaining_time().contains("-") && this.is_shutdown_programed()) {
                // shutdown command only handels minutes when sheduling , not seconds.
                // So we may have passed the time. We check if we are in negative numbers and we shutdown the computer
                Posix.system("shutdown +0");
            }

            this.launcher.progress = get_percentage_progres();
            if (this.shutdown_programed) return true;
            else return false;
        }

    }
