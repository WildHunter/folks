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

public class SetNullAvatarTests : TrackerTest.TestCase
{
  private GLib.MainLoop _main_loop;
  private IndividualAggregator _aggregator;
  private string _persona_fullname;
  private bool _null_avatar_set;

  public SetNullAvatarTests ()
    {
      base ("SetNullAvatarTests");

      this.add_test ("test setting null avatar ", this.test_set_null_avatar);
    }

  public void test_set_null_avatar ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._persona_fullname = "persona #1";

      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._persona_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._null_avatar_set = false;

      this._test_set_null_avatar_async.begin ();

      TestUtils.loop_run_with_timeout (this._main_loop);

      assert (this._null_avatar_set);
    }

  private async void _test_set_null_avatar_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed_detailed.connect
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

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._persona_fullname)
            {
              foreach (var p in i.personas)
                {
                  ((AvatarDetails) p).avatar = null;
                  this._set_null_avatar_async.begin ();
                }
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private async void _set_null_avatar_async ()
    {
      yield _do_set_null_avatar_async ();
      this._main_loop.quit ();
    }

  private async void _do_set_null_avatar_async ()
    {
      this._null_avatar_set = true;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new SetNullAvatarTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
