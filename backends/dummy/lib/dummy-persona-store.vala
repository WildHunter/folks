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

using Folks;
using Gee;
using GLib;

/**
 * A persona store representing a single EDS address book. TODO
 *
 * The persona store will contain {@link Dummy.Persona}s for each contact in the
 * address book it represents.
 *
 * TODO: trust_level and is_user_set_default can be set as normal properties
 *
 * @since UNRELEASED
 */
public class Dummyf.PersonaStore : Folks.PersonaStore
{
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
  private bool _quiescent_on_prepare = false;

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   *
   * @since UNRELEASED
   */
  public override string type_id { get { return BACKEND_NAME; } }

  private MaybeBool _can_add_personas = MaybeBool.FALSE;

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_add_personas
    {
      get
        {
          if (!this._is_prepared)
            {
              return MaybeBool.FALSE;
            }

          return this._can_add_personas;
        }
    }

  private MaybeBool _can_alias_personas = MaybeBool.FALSE;

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_alias_personas
    {
      get
        {
          if (!this._is_prepared)
            {
              return MaybeBool.FALSE;
            }

          return this._can_alias_personas;
        }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_group_personas
    {
      get
        {
          return ("groups" in this._always_writeable_properties)
              ? MaybeBool.TRUE : MaybeBool.FALSE;
        }
    }

  private MaybeBool _can_remove_personas = MaybeBool.FALSE;

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_remove_personas
    {
      get
        {
          if (!this._is_prepared)
            {
              return MaybeBool.FALSE;
            }

          return this._can_remove_personas;
        }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since UNRELEASED
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  private string[] _always_writeable_properties = {};
  private static string[] _always_writeable_properties_empty = {}; /* oh Vala */

  /**
   * {@inheritDoc}
   *
   * @since UNRELEASED
   */
  public override string[] always_writeable_properties
    {
      get
        {
          if (!this._is_prepared)
            {
              return PersonaStore._always_writeable_properties_empty;
            }

          return this._always_writeable_properties;
        }
    }

  /*
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since UNRELEASED
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private HashSet<Persona> _pending_personas = null;

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   *
   * @since UNRELEASED
   */
  public override Map<string, Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   * in ``s``. Passing a re-used source registry to the constructor (compared to
   * the old {@link Dummy.PersonaStore} constructor) saves a lot of time and
   * D-Bus round trips. TODO
   *
   * @param id The new store's ID.
   * @param display_name The new store's display name.
   * @param always_writeable_properties The set of always writeable properties.
   *
   * @since UNRELEASED
   */
  public PersonaStore (string id, string display_name,
      string[] always_writeable_properties)
    {
      Object (
          id: id,
          display_name: display_name);

      this._always_writeable_properties = always_writeable_properties;
    }

  construct
    {
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * Accepted keys for ``details`` are:
   * - PersonaStore.detail_key (PersonaDetail.AVATAR)
   * - PersonaStore.detail_key (PersonaDetail.BIRTHDAY)
   * - PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.FULL_NAME)
   * - PersonaStore.detail_key (PersonaDetail.GENDER)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.IS_FAVOURITE)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.ROLES)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.LOCAL_IDS)
   * - PersonaStore.detail_key (PersonaDetail.WEB_SERVICE_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   * - PersonaStore.detail_key (PersonaDetail.URLS)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the store hasn’t been
   * prepared
   * @throws Folks.PersonaStoreError.CREATE_FAILED if creating the persona in
   * the EDS store failed
   *
   * @since UNRELEASED
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      // We have to have called prepare() beforehand.
      if (!this._is_prepared)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              "Persona store has not yet been prepared.");
        }

      /* TODO: Allow overriding the class used. */
      var persona = new Dummyf.Persona (this, "TODO", false, {});

      var iter = HashTableIter<string, Value?> (details);
      unowned string k;
      unowned Value? _v;

      while (iter.next (out k, out _v) == true)
        {
          if (_v == null)
            {
              continue;
            }
          unowned Value v = (!) _v;

          if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FULL_NAME))
            {
              string? full_name = v.get_string ();
              string _full_name = "";
              if (full_name != null)
                {
                  _full_name = (!) full_name;
                }

              var _persona = persona as NameDetails;
              assert (_persona != null);
              _persona.full_name = _full_name;
            }
          /* TODO */
          /*else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.EMAIL_ADDRESSES))
            {
              Set<EmailFieldDetails> email_addresses =
                (Set<EmailFieldDetails>) v.get_object ();
              this._set_contact_attributes_string (contact,
                  email_addresses,
                  "EMAIL", E.ContactField.EMAIL);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.AVATAR))
            {
              try
                {
                  var avatar = (LoadableIcon?) v.get_object ();
                  yield this._set_contact_avatar (contact, avatar);
                }
              catch (PropertyError e1)
                {
                  warning ("Couldn't set avatar on the EContact: %s",
                      e1.message);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IM_ADDRESSES))
            {
              var im_fds = (MultiMap<string, ImFieldDetails>) v.get_object ();
              this._set_contact_im_fds (contact, im_fds);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              Set<PhoneFieldDetails> phone_numbers =
                (Set<PhoneFieldDetails>) v.get_object ();
              this._set_contact_attributes_string (contact,
                  phone_numbers, "TEL",
                  E.ContactField.TEL);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              Set<PostalAddressFieldDetails> postal_fds =
                (Set<PostalAddressFieldDetails>) v.get_object ();
              this._set_contact_postal_addresses (contact, postal_fds);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.STRUCTURED_NAME))
            {
              StructuredName sname = (StructuredName) v.get_object ();
              this._set_contact_name (contact, sname);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.LOCAL_IDS))
            {
              Set<string> local_ids = (Set<string>) v.get_object ();
              this._set_contact_local_ids (contact, local_ids);
            }
          else if (k == Folks.PersonaStore.detail_key
              (PersonaDetail.WEB_SERVICE_ADDRESSES))
            {
              HashMultiMap<string, WebServiceFieldDetails>
                web_service_addresses =
                (HashMultiMap<string, WebServiceFieldDetails>) v.get_object ();
              this._set_contact_web_service_addresses (contact,
                  web_service_addresses);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.HashSet<NoteFieldDetails>) v.get_object ();
              this._set_contact_notes (contact, notes);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GENDER))
            {
              var gender = (Gender) v.get_enum ();
              this._set_contact_gender (contact, gender);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.URLS))
            {
              Set<UrlFieldDetails> urls = (Set<UrlFieldDetails>) v.get_object ();
              this._set_contact_urls (contact, urls);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY))
            {
              var birthday = (DateTime?) v.get_boxed ();
              this._set_contact_birthday (contact, birthday);
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.ROLES))
            {
              Set<RoleFieldDetails> roles =
                (Set<RoleFieldDetails>) v.get_object ();
              this._set_contact_roles (contact, roles);
            }
          else if (k == Folks.PersonaStore.detail_key (
                  PersonaDetail.IS_FAVOURITE))
            {
              bool is_fav = v.get_boolean ();
              this._set_contact_is_favourite (contact, is_fav);
            }*/
        }

      /* TODO: How to simulate failure? */
      this._personas.set (persona.iid, persona);

      /* Notify of the new persona. */
      var added_personas = new HashSet<Persona> ();
      added_personas.add (persona);
      this._emit_personas_changed (added_personas, null);

      return persona;
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @param persona the persona that should be removed
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the store hasn’t been
   * prepared or has gone offline
   * @throws Folks.PersonaStoreError.PERMISSION_DENIED if the store denied
   * permission to delete the contact
   * @throws Folks.PersonaStoreError.READ_ONLY if the store is read only
   * @throws Folks.PersonaStoreError.REMOVE_FAILED if any other errors happened
   * in the store
   *
   * @since UNRELEASED
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      // We have to have called prepare() beforehand.
      if (!this._is_prepared)
        {
          throw new PersonaStoreError.STORE_OFFLINE (
              "Persona store has not yet been prepared.");
        }

      /* TODO: How to simulate failure? */
      Persona? _persona = this._personas.get (persona.iid);
      if (persona != null)
        {
          this._personas.unset (persona.iid);

          /* Handle the case where a contact is removed before the persona
           * store has reached quiescence. */
          if (this._pending_personas != null)
            {
              this._pending_personas.remove ((!) _persona);
            }

          /* Notify of the removal. */
          var removed_personas = new HashSet<Folks.Persona> ();
          removed_personas.add ((!) persona);
          this._emit_personas_changed (null, removed_personas);
        }
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   *
   * @throws Folks.PersonaStoreError.STORE_OFFLINE if the EDS store is offline
   * @throws Folks.PersonaStoreError.PERMISSION_DENIED if permission was denied
   * to open the EDS store
   * @throws Folks.PersonaStoreError.INVALID_ARGUMENT if any other error
   * occurred in the EDS store
   *
   * @since UNRELEASED
   */
  public override async void prepare () throws PersonaStoreError
    {
      Internal.profiling_start ("preparing Dummy.PersonaStore (ID: %s)",
          this.id);

      if (this._is_prepared == true || this._prepare_pending == true)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          /* If reach_quiescence() has been called already, signal
           * quiescence. */
          if (this._quiescent_on_prepare == true)
            {
              this.reach_quiescence ();
            }
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Dummy.PersonaStore");
    }

  /**
   * TODO
   *
   * @param can_add_personas TODO
   * @param can_alias_personas TODO
   * @param can_remove_personas TODO
   * @since UNRELEASED
   */
  public void set_capabilities (MaybeBool can_add_personas,
      MaybeBool can_alias_personas, MaybeBool can_remove_personas)
    {
      this.freeze_notify ();

      if (can_add_personas != this._can_add_personas)
        {
          this._can_add_personas = can_add_personas;
          this.notify_property ("can-add-personas");
        }

      if (can_alias_personas != this._can_alias_personas)
        {
          this._can_alias_personas = can_alias_personas;
          this.notify_property ("can-alias-personas");
        }

      if (can_remove_personas != this._can_remove_personas)
        {
          this._can_remove_personas = can_remove_personas;
          this.notify_property ("can-remove-personas");
        }

      this.thaw_notify ();
    }

  /**
   * TODO
   *
   * @param personas TODO
   * @since UNRELEASED
   */
  public void register_personas (Set<Persona> personas)
    {
      HashSet<Persona> added_personas;

      /* If the persona store hasn't yet reached quiescence, queue up the
       * personas and emit a notification about them later.. */
      if (this._is_quiescent == false)
        {
          /* Lazily create pending_personas. */
          if (this._pending_personas == null)
            {
              this._pending_personas = new HashSet<Persona> ();
            }

          added_personas = this._pending_personas;
        }
      else
        {
          added_personas = new HashSet<Persona> ();
        }

      foreach (var persona in personas)
        {
          if (!this._personas.has_key (persona.iid))
            {
              this._personas.set (persona.iid, persona);
              added_personas.add (persona);
            }
        }

      if (added_personas.size > 0 && this._is_quiescent == true)
        {
          this._emit_personas_changed (added_personas, null);
        }
    }

  /**
   * TODO
   *
   * @param personas TODO
   * @since UNRELEASED
   */
  public void unregister_personas (Set<Persona> personas)
    {
      var removed_personas = new HashSet<Persona> ();

      foreach (var _persona in personas)
        {
          Persona? persona = this._personas.get (_persona.iid);
          if (persona != null)
            {
              removed_personas.add ((!) persona);
              this._personas.unset (((!) persona).iid);

              /* Handle the case where a contact is removed before the persona
               * store has reached quiescence. */
              if (this._pending_personas != null)
                {
                  this._pending_personas.remove ((!) persona);
                }
            }
        }

       if (removed_personas.size > 0)
         {
           this._emit_personas_changed (null, removed_personas);
         }
    }

/* TODO: Some method of emitting _emit_personas_changed with no null values */

  /**
   * TODO
   *
   * @since UNRELEASED
   */
  public void reach_quiescence ()
    {
      /* Can't reach quiescence until prepare() has been called. */
      if (this._is_prepared == false)
        {
          this._quiescent_on_prepare = true;
          return;
        }

      /* The initial query is complete, so signal that we've reached
       * quiescence (even if there was an error). */
      if (this._is_quiescent == false)
        {
          /* Emit a notification about all the personas which were found in the
           * initial query. They're queued up in _contacts_added_cb() and only
           * emitted here as _contacts_added_cb() may be called many times
           * before _contacts_complete_cb() is called. For example, EDS seems to
           * like emitting contacts in batches of 16 at the moment.
           * Queueing the personas up and emitting a single notification is a
           * lot more efficient for the individual aggregator to handle. */
          if (this._pending_personas != null)
            {
              this._emit_personas_changed (this._pending_personas, null);
              this._pending_personas = null;
            }

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
    }
}
