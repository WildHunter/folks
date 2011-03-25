/*
 * Copyright (C) 2011 Collabora Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker.Sparql;
using TrackerTest;
using Folks;
using Gee;

public class FavouriteDetailsInterfaceTests : Folks.TestCase
{
  private TrackerTest.Backend _tracker_backend;
  private GLib.MainLoop _main_loop;
  private string _fullname_p1;
  private string _fullname_p2;
  private string _fullname_p3;
  private bool _found_p1;
  private bool _found_p2;
  private bool _found_p3;
  private IndividualAggregator _aggregator;

  public FavouriteDetailsInterfaceTests ()
    {
      base ("FavouriteDetailsInterfaceTests");

      this._tracker_backend = new TrackerTest.Backend ();

      this.add_test ("test favourite details interface",
          this.test_favourite_details_interface);
    }

  public override void set_up ()
    {
    }

  public override void tear_down ()
    {
    }

  public void test_favourite_details_interface ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c2 = new Gee.HashMap<string, string> ();
      Gee.HashMap<string, string> c3 = new Gee.HashMap<string, string> ();
      this._fullname_p1 = "favourite persona #1";
      this._fullname_p2 = "favourite persona #2";
      this._fullname_p3 = "favourite persona #3";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p1);
      c1.set (Trf.OntologyDefs.NAO_TAG, "");
      this._tracker_backend.add_contact (c1);

      c2.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p2);
      c2.set (Trf.OntologyDefs.NAO_TAG, "");
      this._tracker_backend.add_contact (c2);

      c3.set (Trf.OntologyDefs.NCO_FULLNAME, this._fullname_p3);
      this._tracker_backend.add_contact (c3);

      this._tracker_backend.set_up ();

      this._found_p1 = false;
      this._found_p2 = false;
      this._found_p3 = false;

      this._test_favourite_details_interface_async ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          return false;
        });

      this._main_loop.run ();

      assert (this._found_p1 == true);
      assert (this._found_p2 == true);
      assert (this._found_p3 == true);

      this._tracker_backend.tear_down ();
    }

  private async void _test_favourite_details_interface_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_cb
      (GLib.List<Individual>? added,
       GLib.List<Individual>? removed,
       string? message,
       Persona? actor,
       GroupDetails.ChangeReason reason)
    {
      foreach (Individual i in added)
        {
          string full_name = i.full_name;
          if (full_name != null)
            {
              if (full_name == this._fullname_p1)
                {
                  assert (i.is_favourite == true);
                  this._found_p1 = true;
                }
              else if (full_name == this._fullname_p2)
                {
                  assert (i.is_favourite == true);
                  this._found_p2 = true;
                }
              else if (full_name == this._fullname_p3)
                {
                  assert (i.is_favourite == false);
                  this._found_p3 = true;
                }
            }
        }

        assert (removed == null);

        if (this._found_p1 &&
            this._found_p2 &&
            this._found_p3)
          this._main_loop.quit ();
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new FavouriteDetailsInterfaceTests ().get_suite ());

  Test.run ();

  return 0;
}