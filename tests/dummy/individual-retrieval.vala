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
 * Authors: Renato Araujo Oliveira Filho <renato@canonical.com>
 */

using Gee;
using Folks;
using DummyTest;

public class IndividualRetrievalTests : DummyTest.TestCase
{
  public IndividualRetrievalTests ()
    {
      base ("IndividualRetrieval");

      this.add_test ("singleton individuals", this.test_singleton_individuals);
      this.add_test ("aliases", this.test_aliases);
    }

  public void test_singleton_individuals ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      
      Dummy.PersonaStore dummy_persona_store = new Dummy.PersonaStore();
      dummy_persona_store.add_persona_from_details(details);
    }

  public void test_aliases ()
    {
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new IndividualRetrievalTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
