/*
 * Copyright (C) 2013 Philip Withnall
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
 * Authors:
 *       Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using GLib;
using Folks;

extern const string BACKEND_NAME;

/**
 * A backend which connects to EDS and creates a {@link PersonaStore}
 * for each service. TODO
 *
 * @since UNRELEASED
 */
public class Dummyf.Backend : Folks.Backend
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;

  private HashMap<string, PersonaStore> _all_persona_stores;
  private HashMap<string, PersonaStore> _enabled_persona_stores;
  private Map<string, PersonaStore> _enabled_persona_stores_ro;

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public Backend ()
    {
      Object ();
    }

  construct
    {
      this._all_persona_stores = new HashMap<string, PersonaStore> ();
      this._enabled_persona_stores = new HashMap<string, PersonaStore> ();
      this._enabled_persona_stores_ro =
          this._enabled_persona_stores.read_only_view;
    }

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   *
   * @since UNRELEASED
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this Backend has reached a quiescent state.
   *
   * See {@link Folks.Backend.is_quiescent}.
   *
   * @since UNRELEASED
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override Map<string, PersonaStore> persona_stores
    {
      get { return this._enabled_persona_stores_ro; }
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override void disable_persona_store (Folks.PersonaStore store)
    {
      this._disable_persona_store (store);
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override void enable_persona_store (Folks.PersonaStore store)
    {
      this._enable_persona_store ((Dummyf.PersonaStore) store);
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override void set_persona_stores (Set<string>? store_ids)
    {
      /* If the set is empty, load all unloaded stores then return. */
      if (store_ids == null)
        {
          this.freeze_notify ();
          foreach (var store in this._all_persona_stores.values)
            {
              this._enable_persona_store (store);
            }
          this.thaw_notify ();

          return;
        }

      /* First handle adding any missing persona stores. */
      this.freeze_notify ();

      foreach (var id in store_ids)
        {
          if (!this._enabled_persona_stores.has_key (id))
            {
              var store = this._all_persona_stores.get (id);
              if (store != null)
                {
                  this._enable_persona_store (store);
                }
            }
        }

      /* Keep persona stores to remove in a separate array so we don't
       * invalidate the list we are iterating over. */
      PersonaStore[] stores_to_remove = {};

      foreach (var store in this._enabled_persona_stores.values)
        {
          if (!store_ids.contains (store.id))
            {
              stores_to_remove += store;
            }
        }

      foreach (var store in stores_to_remove)
        {
          this._disable_persona_store (store);
        }

      this.thaw_notify ();
    }

  private void _enable_persona_store (PersonaStore store)
    {
      if (this._enabled_persona_stores.has_key (store.id))
        {
          return;
        }
      assert (this._all_persona_stores.has_key (store.id));

      store.removed.connect (this._store_removed_cb);

      this._enabled_persona_stores.set (store.id, store);

      this.persona_store_added (store);
      this.notify_property ("persona-stores");
    }

  private void _disable_persona_store (Folks.PersonaStore store)
    {
      if (!this._enabled_persona_stores.unset (store.id))
        {
          return;
        }
      assert (this._all_persona_stores.has_key (store.id));

      this.persona_store_removed (store);
      this.notify_property ("persona-stores");

      store.removed.disconnect (this._store_removed_cb);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      this._disable_persona_store (store);
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Dummy.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Dummy.Backend");
    }

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          foreach (var persona_store in this._enabled_persona_stores.values)
            {
              this._disable_persona_store (persona_store);
            }

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }
    }

  /**
   * TODO
   *
   * @since UNRELEASED
   */
  public void register_persona_stores (Set<PersonaStore> stores)
    {
      foreach (var store in stores)
        {
          if (this._all_persona_stores.has_key (store.id))
            {
              continue;
            }

          this._all_persona_stores.set (store.id, store);
          this._enable_persona_store (store);
        }
    }

  /**
   * TODO
   *
   * @since UNRELEASED
   */
  public void unregister_persona_stores (Set<PersonaStore> stores)
    {
      foreach (var store in stores)
        {
          if (!this._all_persona_stores.has_key (store.id))
            {
              continue;
            }

          this._disable_persona_store (store);
          this._all_persona_stores.unset (store.id);
        }
    }
}
