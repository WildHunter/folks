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

  private void add_persona_renato()
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);

      // FullName
      Value? v1 = Value (typeof (string));
      v1.set_string ("Renato Araujo Oliveira Filho");
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      // Emails
      Value? v2 = Value (typeof (Set));
      var emails = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var email_1 = new EmailFieldDetails ("renato@canonical.com");
      email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      emails.add (email_1);
      v2.set_object (emails);

      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v2);

      //Ims
      Value? v4 = Value (typeof (MultiMap));
      var im_fds = new HashMultiMap<string, ImFieldDetails> ();
      im_fds.set ("jabber", new ImFieldDetails ("renato@jabber.com"));
      im_fds.set ("yahoo", new ImFieldDetails ("renato@yahoo.com"));
      v4.set_object (im_fds);
      details.insert (
         Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v4);

      this.dummy_persona_store.add_persona_from_details.begin(details, (obj, res) => {
        try { 
          this.dummy_persona_store.add_persona_from_details.end(res);
        } catch (GLib.Error e) {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        } 
      });
    }

  private void add_persona_rodrigo()
    {
      HashTable<string, Value?> details = new HashTable<string, Value?>
          (str_hash, str_equal);

      // FullName
      Value? v1 = Value (typeof (string));
      v1.set_string ("Rodrigo Almeida");
      details.insert (Folks.PersonaStore.detail_key (PersonaDetail.FULL_NAME),
          (owned) v1);

      // Emails
      Value? v2 = Value (typeof (Set));
      var emails = new HashSet<EmailFieldDetails> (
          AbstractFieldDetails<string>.hash_static,
          AbstractFieldDetails<string>.equal_static);

      var email_1 = new EmailFieldDetails ("rodrigo@gmail.com");
      email_1.set_parameter (AbstractFieldDetails.PARAM_TYPE,
          AbstractFieldDetails.PARAM_TYPE_HOME);
      emails.add (email_1);
      v2.set_object (emails);

      details.insert (
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          (owned) v2);

      //Ims
      Value? v4 = Value (typeof (MultiMap));
      var im_fds = new HashMultiMap<string, ImFieldDetails> ();
      im_fds.set ("jabber", new ImFieldDetails ("rodrigo@jabber.com"));
      im_fds.set ("yahoo", new ImFieldDetails ("rodrigo@yahoo.com"));
      v4.set_object (im_fds);
      details.insert (
         Folks.PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES), v4);

      this.dummy_persona_store.add_persona_from_details.begin(details, (obj, res) => {
        try { 
          this.dummy_persona_store.add_persona_from_details.end(res);
        } catch (GLib.Error e) {
          GLib.warning ("[AddPersonaError] add_persona_from_details: %s\n",
              e.message);
        } 
      });
    }


  public void test_singleton_individuals ()
    {      
      var main_loop = new GLib.MainLoop (null, false);
      this.add_persona_renato();
      this.add_persona_rodrigo();

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      uint individuals_changed_count = 0;
      aggregator.individuals_changed_detailed.connect ((changes) =>
        {
          var added = changes.get_values ();
          //var removed = changes.get_keys ();

          individuals_changed_count++;

          assert (added.size == 1);
          //assert (removed.size == 1);

          /* Check properties */
          foreach (var i in added)
            {
              GLib.debug ("Contact added: %s\n", i.full_name);
            }
        });
      aggregator.prepare.begin ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      TestUtils.loop_run_with_timeout (main_loop, 3);
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
