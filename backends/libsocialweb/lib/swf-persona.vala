/*
 * Copyright (C) 2010 Collabora Ltd.
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
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using SocialWebClient;

/**
 * A persona subclass which represents a single libsocialweb contact.
 */
public class Swf.Persona : Folks.Persona,
    AvatarDetails,
    GenderDetails,
    ImDetails,
    NameDetails,
    UrlDetails,
    WebServiceDetails
{
  private const string[] _linkable_properties =
    {
      "im-addresses",
      "web-service-addresses"
    };

  /* No writeable properties
   *
   * FIXME: we can't mark this as const because Vala gets confused
   *        and generates the wrong C output (char *arr[0] = {}
   *        instead of char **arr = NULL)
   */
  private static string[] _writeable_properties = {};

  /**
   * The names of the Persona's linkable properties.
   *
   * See {@link Folks.Persona.linkable_properties}.
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override string[] writeable_properties
    {
      get { return this._writeable_properties; }
    }

  private LoadableIcon? _avatar = null;

  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.AvatarDetails.avatar}.
   *
   * @since 0.6.0
   */
  [CCode (notify = false)]
  public LoadableIcon? avatar
    {
      get { return this._avatar; }
      set { this.change_avatar.begin (value); } /* not writeable */
    }

  private StructuredName? _structured_name = null;

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public StructuredName? structured_name
    {
      get { return this._structured_name; }
      set { this.change_structured_name.begin (value); } /* not writeable */
    }

  private string _full_name = "";

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public string full_name
    {
      get { return this._full_name; }
      set { this.change_full_name.begin (value); } /* not writeable */
    }

  private string _nickname = "";

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public string nickname
    {
      get { return this._nickname; }
      set { this.change_nickname.begin (value); } /* not writeable */
    }

  private Gender _gender = Gender.UNSPECIFIED;

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public Gender gender
    {
      get { return this._gender; }
      set { this.change_gender.begin (value); } /* not writeable */
    }

  private HashSet<UrlFieldDetails> _urls;
  private Set<UrlFieldDetails> _urls_ro;

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public Set<UrlFieldDetails> urls
    {
      get { return this._urls_ro; }
      set { this.change_urls.begin (value); } /* not writeable */
    }

  private HashMultiMap<string, ImFieldDetails> _im_addresses =
      new HashMultiMap<string, ImFieldDetails> (null, null,
          ImFieldDetails.hash, (EqualFunc) ImFieldDetails.equal);

  private HashMultiMap<string, WebServiceFieldDetails> _web_service_addresses =
      new HashMultiMap<string, WebServiceFieldDetails> (
          null, null,
          (GLib.HashFunc) WebServiceFieldDetails.hash,
          (GLib.EqualFunc) WebServiceFieldDetails.equal);

  /**
   * {@inheritDoc}
   */
  [CCode (notify = false)]
  public MultiMap<string, ImFieldDetails> im_addresses
    {
      get { return this._im_addresses; }
      set { this.change_im_addresses.begin (value); }
    }

  /**
   * {@inheritDoc}
   */
  public MultiMap<string, string> web_service_addresses
    {
      get { return this._web_service_addresses; }
      private set {}
    }

  private Contact _lsw_contact;

  /**
   * The Contact from libsocialweb
   */
  public Contact lsw_contact
    {
      get { return this._lsw_contact; }
      private set
        {
          if (_lsw_contact != null && _lsw_contact != value)
            {
              _lsw_contact.unref ();
            }
          this._lsw_contact = value.ref ();
        }
    }

  /**
   * Build the Facebook JID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param lsw_id the lsw id
   * @return the Facebook JID or null if it is not a Facebook contact
   *
   * @since 0.5.0
   */
  internal static string? _build_facebook_jid (string store_id, string lsw_id)
    {
      string facebook_jid = null;
      if (store_id == "facebook" && "facebook-" in lsw_id)
        {
          /* The lsw_id is in the form "facebook-XXXX", while the JID is
           * "-XXXX@chat.facebook.com". */
          facebook_jid = lsw_id.replace("facebook", "") + "@chat.facebook.com";
        }
      return facebook_jid;
    }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param lsw_id the lsw id
   * @return a valid IID
   *
   * @since 0.5.0
   */
  internal static string _build_iid (string store_id, string lsw_id)
    {
      /* This is a hack so that Facebook contacts from libsocialweb are
       * automatically merged with Facebook contacts from Telepathy
       * because they have the same iid. */
      string facebook_jid = null;
      string iid;
      facebook_jid = _build_facebook_jid (store_id, lsw_id);
      if (facebook_jid != null)
        {
          iid = "jabber:" + facebook_jid;
        }
      else
        {
          iid = store_id + ":" + lsw_id;
        }
      return iid;
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the libsocialweb contact given by `contact`.
   */
  public Persona (PersonaStore store, Contact contact)
    {
      var id = get_contact_id (contact);
      var service = contact.service.dup();
      var uid = this.build_uid (BACKEND_NAME, store.id, id);
      var iid = this._build_iid (store.id, id);

      Object (display_id: id,
              uid: uid,
              iid: iid,
              store: store,
              is_user: false);
      this.lsw_contact = contact;

      debug ("Creating new Sw.Persona '%s' for %s UID '%s': %p",
          uid, store.display_name, id, this);

      var facebook_jid = this._build_facebook_jid (store.id, id);
      if (facebook_jid != null)
        {
          try
            {
              var facebook_jid_copy = facebook_jid.dup();
              var normalised_addr = (owned) normalise_im_address
                  ((owned) facebook_jid_copy, "jabber");
              string im_proto = "jabber";
              var im_fd = new ImFieldDetails (normalised_addr);

              this._im_addresses.set (im_proto, im_fd);
            }
          catch (ImDetailsError e)
            {
              warning (e.message);
            }
        }

      this._web_service_addresses.set (service,
          new WebServiceFieldDetails (id));

      update (contact);
    }

  ~Persona ()
    {
      debug ("Destroying Sw.Persona '%s': %p", this.uid, this);
      this._lsw_contact.unref ();
      this._lsw_contact = null;
    }

  public static string? get_contact_id (Contact contact)
    {
      return contact.get_value ("id");
    }

  public void update (Contact contact)
    {
      var nickname = contact.get_value ("name");
      if (nickname != null && this._nickname != nickname)
        {
          this._nickname = nickname;
          this.notify_property ("nickname");
        }

      var avatar_path = contact.get_value ("icon");
      if (avatar_path != null)
        {
          var icon = new FileIcon (File.new_for_path (avatar_path));
          if (this._avatar == null || !this._avatar.equal (icon))
            {
              this._avatar = icon;
              this.notify_property ("avatar");
            }
        }
      else
        {
          this._avatar = null;
          this.notify_property ("avatar");
        }

      var structured_name = new StructuredName.simple (
          contact.get_value ("n.family"), contact.get_value ("n.given"));
      if (!structured_name.is_empty ())
        {
          this._structured_name = structured_name;
          this.notify_property ("structured-name");
        }
      else if (this.structured_name != null)
        {
          this._structured_name = null;
          this.notify_property ("structured-name");
        }

      var full_name = contact.get_value ("fn");
      if (this._full_name != full_name)
        {
          this._full_name = full_name;
          this.notify_property ("full-name");
        }

      var urls = new HashSet<UrlFieldDetails> (
          (GLib.HashFunc) UrlFieldDetails.hash,
          (GLib.EqualFunc) UrlFieldDetails.equal);

      var website = contact.get_value ("url");
      if (website != null)
        urls.add (new UrlFieldDetails (website));

      /* https://bugzilla.gnome.org/show_bug.cgi?id=645139
      string[] websites = contact.get_value_all ("url");
      foreach (string website in websites)
        urls.add (new UrlFieldDetails (website));
      */
      if (this._urls != urls)
        {
          this._urls = urls;
          this._urls_ro = urls.read_only_view;
          this.notify_property ("urls");
        }

      var gender_string = contact.get_value ("x-gender");
      Gender gender;
      if (gender_string != null && gender_string.down() == "male")
        gender = Gender.MALE;
      else if (gender_string != null && gender_string.down() == "female")
        gender = Gender.FEMALE;
      else
        gender = Gender.UNSPECIFIED;
      if (this._gender != gender)
        {
          this._gender = gender;
          this.notify_property ("gender");
        }
    }
}
