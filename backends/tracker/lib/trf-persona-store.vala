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
 * Authors:
 *         Travis Reitter <travis.reitter@collabora.co.uk>
 *         Philip Withnall <philip.withnall@collabora.co.uk>
 *         Marco Barisione <marco.barisione@collabora.co.uk>
 *         Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using Folks;
using GLib;
using Tracker;
using Tracker.Sparql;

extern const string BACKEND_NAME;

internal enum Trf.Fields
{
  TRACKER_ID,
  FULL_NAME,
  FAMILY_NAME,
  GIVEN_NAME,
  ADDITIONAL_NAMES,
  PREFIXES,
  SUFFIXES,
  ALIAS,
  BIRTHDAY,
  AVATAR_URL,
  IM_ADDRESSES,
  PHONES,
  EMAILS,
  URLS,
  FAVOURITE,
  CONTACT_URN,
  ROLES,
  NOTE,
  GENDER,
  POSTAL_ADDRESS
}

internal enum Trf.AfflInfoFields
{
  IM_TRACKER_ID,
  IM_PROTOCOL,
  IM_ACCOUNT_ID,
  AFFL_TRACKER_ID,
  AFFL_ROLE,
  AFFL_ORG,
  AFFL_POBOX,
  AFFL_DISTRICT,
  AFFL_COUNTY,
  AFFL_LOCALITY,
  AFFL_POSTALCODE,
  AFFL_STREET_ADDRESS,
  AFFL_ADDRESS_LOCATION,
  AFFL_EXTENDED_ADDRESS,
  AFFL_COUNTRY,
  AFFL_REGION,
  AFFL_EMAIL,
  AFFL_PHONE,
  AFFL_WEBSITE,
  AFFL_BLOG,
  AFFL_URL,
  IM_NICKNAME
}

internal enum Trf.PostalAddressFields
{
  TRACKER_ID,
  POBOX,
  DISTRICT,
  COUNTY,
  LOCALITY,
  POSTALCODE,
  STREET_ADDRESS,
  ADDRESS_LOCATION,
  EXTENDED_ADDRESS,
  COUNTRY,
  REGION
}

internal enum Trf.UrlsFields
{
  TRACKER_ID,
  BLOG,
  WEBSITE,
  URL
}

internal enum Trf.RoleFields
{
  TRACKER_ID,
  ROLE,
  DEPARTMENT
}

internal enum Trf.IMFields
{
  TRACKER_ID,
  PROTO,
  ID,
  IM_NICKNAME
}

internal enum Trf.PhoneFields
{
  TRACKER_ID,
  PHONE
}

internal enum Trf.EmailFields
{
  TRACKER_ID,
  EMAIL
}

internal enum Trf.TagFields
{
  TRACKER_ID
}

private enum Trf.Attrib
{
  EMAILS,
  PHONES,
  URLS,
  IM_ADDRESSES,
  POSTAL_ADDRESSES
}

private const char _REMOVE_ALL_ATTRIBS = 0x01;
private const char _REMOVE_PHONES      = 0x02;
private const char _REMOVE_POSTALS     = 0x04;
private const char _REMOVE_IM_ADDRS    = 0x08;
private const char _REMOVE_EMAILS      = 0x10;

/**
 * A persona store.
 * It will create {@link Persona}s for each contacts on the main addressbook.
 */
public class Trf.PersonaStore : Folks.PersonaStore
{
  private const string _OBJECT_NAME = "org.freedesktop.Tracker1";
  private const string _OBJECT_IFACE = "org.freedesktop.Tracker1.Resources";
  private const string _OBJECT_PATH = "/org/freedesktop/Tracker1/Resources";
  private HashTable<string, Persona> _personas;
  private bool _is_prepared = false;
  private static const int _default_timeout = 100;
  private Resources _resources_object;
  private Tracker.Sparql.Connection _connection;
  private static Gee.TreeMap<string, string> _urn_prefix = null;
  private static Gee.TreeMap<string, int> _prefix_tracker_id = null;
  private static const string _INITIAL_QUERY =
    "SELECT " +
    "tracker:id(?_contact) " +
    "nco:fullname(?_contact) " +
    "nco:nameFamily(?_contact) " +
    "nco:nameGiven(?_contact) " +
    "nco:nameAdditional(?_contact) " +
    "nco:nameHonorificPrefix(?_contact) " +
    "nco:nameHonorificSuffix(?_contact) " +
    "nco:nickname(?_contact) " +
    "nco:birthDate(?_contact) " +
    "nie:url(nco:photo(?_contact)) " +

    /* keep synced with Trf.IMFields */
    "(SELECT " +
    "GROUP_CONCAT ( " +
    " fn:concat(tracker:id(?affl),'\t'," +
    " tracker:coalesce(nco:imProtocol(?a),''), " +
    "'\t', tracker:coalesce(nco:imID(?a),''), '\t'," +
    " tracker:coalesce(nco:imNickname(?a),'')), '\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl. " +
    " ?affl nco:hasIMAddress ?a } ) " +

    /* keep synced with Trf.PhoneFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl),'\t', " +
    " nco:phoneNumber(?aff_number)), " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl . " +
    " ?affl nco:hasPhoneNumber ?aff_number  } ) " +

    /* keep synced with Trf.EmailFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  nco:emailAddress(?emailaddress)), " +
    "',') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl . " +
    " ?affl nco:hasEmailAddress ?emailaddress }) " +

    /* keep synced with Trf.UrlsFields */
    " (SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t'," +
    "  tracker:coalesce(nco:blogUrl(?affl),'')," +
    "  '\t'," +
    "  tracker:coalesce(nco:websiteUrl(?affl),'')" +
    "  , '\t'," +
    "  tracker:coalesce(nco:url(?affl),''))," +
    "  '\\n') " +
    "WHERE { ?_contact nco:hasAffiliation ?affl  } )" +

    /* keep synced with Trf.TagFields */
    "(SELECT " +
    "GROUP_CONCAT(tracker:id(?_tag), " +
    "',') " +
    "WHERE { ?_contact nao:hasTag " +
    "?_tag }) " +

    "?_contact " +

    /* keep synced with Trf.RoleFields */
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  tracker:coalesce(nco:role(?affl),''), '\t', " +
    "  tracker:coalesce(nco:department(?affl),'')),  " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation " +
    "?affl }) " +

    "nco:note(?_contact) " +
    "tracker:id(nco:gender(?_contact)) " +

    /* keep synced with Trf.PostalAddressFields*/
    "(SELECT " +
    "GROUP_CONCAT " +
    " (fn:concat(tracker:id(?affl), '\t', " +
    "  tracker:coalesce(nco:pobox(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:district(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:county(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:locality(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:postalcode(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:streetAddress(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:addressLocation(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:extendedAddress(?postal)" +
    "  ,''), '\t', " +
    "  tracker:coalesce(nco:country(?postal),'')" +
    "  , '\t', " +
    "  tracker:coalesce(nco:region(?postal),'')),  " +
    "'\\n') " +
    "WHERE { ?_contact nco:hasAffiliation " +
    "?affl . ?affl nco:hasPostalAddress ?postal }) " +

    "{ ?_contact a nco:PersonContact . %s } " +
    "ORDER BY tracker:id(?_contact) ";


  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.TRUE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
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
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since UNRELEASED
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.TRUE; }
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

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override HashTable<string, Persona> personas
    {
      get { return this._personas; }
    }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   */
  public PersonaStore ()
    {
      Object (id: BACKEND_NAME, display_name: BACKEND_NAME);
      this._personas = new HashTable<string, Persona> (str_hash, str_equal);
      debug ("Initial query : \n%s\n", this._INITIAL_QUERY);
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * Accepted keys for `details` are:
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.ALIAS)
   * - PersonaStore.detail_key (PersonaDetail.FULL_NAME)
   * - PersonaStore.detail_key (PersonaDetail.FAVOURITE)
   * - PersonaStore.detail_key (PersonaDetail.STRUCTURED_NAME)
   * - PersonaStore.detail_key (PersonaDetail.AVATAR)
   * - PersonaStore.detail_key (PersonaDetail.BIRTHDAY)
   * - PersonaStore.detail_key (PersonaDetail.GENDER)
   * - PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.IM_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.NOTES)
   * - PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS)
   * - PersonaStore.detail_key (PersonaDetail.POSTAL_ADDRESSES)
   * - PersonaStore.detail_key (PersonaDetail.ROLES)
   * - PersonaStore.detail_key (PersonaDetail.URL)
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);
      builder.subject ("_:p");
      builder.predicate ("a");
      builder.object ("nco:PersonContact");

      foreach (var k in details.get_keys ())
        {
          Value? v = details.lookup (k);
          if (k == Folks.PersonaStore.detail_key (PersonaDetail.ALIAS))
            {
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_NICKNAME);
              builder.object_string (v.get_string ());
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FULL_NAME))
            {
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_FULLNAME);
              builder.object_string (v.get_string ());
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.STRUCTURED_NAME))
            {
              StructuredName sname = (StructuredName) v.get_object ();
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_FAMILY);
              builder.object_string (sname.family_name);
              builder.predicate (Trf.OntologyDefs.NCO_GIVEN);
              builder.object_string (sname.given_name);
              builder.predicate (Trf.OntologyDefs.NCO_ADDITIONAL);
              builder.object_string (sname.additional_names);
              builder.predicate (Trf.OntologyDefs.NCO_SUFFIX);
              builder.object_string (sname.suffixes);
              builder.predicate (Trf.OntologyDefs.NCO_PREFIX);
              builder.object_string (sname.prefixes);
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.FAVOURITE))
            {
              if (v.get_boolean ())
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NAO_TAG);
                  builder.object (Trf.OntologyDefs.NAO_FAVORITE);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.AVATAR))
            {
              var avatar = (File) v.get_object ();
              builder.subject ("_:photo");
              builder.predicate ("a");
              builder.object ("nfo:Image, nie:DataObject");
              builder.predicate (Trf.OntologyDefs.NIE_URL);
              builder.object_string (avatar.get_uri ());
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_PHOTO);
              builder.object ("_:photo");
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY))
            {
              var birthday = (DateTime) v.get_boxed ();
              builder.subject ("_:p");
              builder.predicate (Trf.OntologyDefs.NCO_BIRTHDAY);
              TimeVal tv;
              birthday.to_timeval (out tv);
              builder.object_string (tv.to_iso8601 ());
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.GENDER))
            {
              var gender = (Gender) v.get_enum ();
              if (gender != Gender.UNSPECIFIED)
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_GENDER);
                  if (gender == Gender.MALE)
                    builder.object (Trf.OntologyDefs.NCO_MALE);
                  else
                    builder.object (Trf.OntologyDefs.NCO_FEMALE);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.EMAIL_ADDRESSES))
            {
              unowned GLib.List<FieldDetails> email_addresses =
                (GLib.List<FieldDetails>) v.get_pointer ();
              int email_cnt = 0;
              foreach (var e in email_addresses)
                {
                  var email_affl = "_:email_affl%d".printf (email_cnt);
                  var email = yield this._urn_from_property (
                      Trf.OntologyDefs.NCO_EMAIL,
                      Trf.OntologyDefs.NCO_EMAIL_PROP, e.value);

                  if (email == "")
                    {
                      email = "_:email%d".printf (email_cnt);
                      builder.subject (email);
                      builder.predicate ("a");
                      builder.object (Trf.OntologyDefs.NCO_EMAIL);
                      builder.predicate (Trf.OntologyDefs.NCO_EMAIL_PROP);
                      builder.object_string (e.value);
                    }

                  builder.subject (email_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_EMAIL);
                  builder.object (email);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (email_affl);

                  email_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.IM_ADDRESSES))
            {
              var im_addresses =
                (HashTable<string, LinkedHashSet<string>>) v.get_boxed ();

              int im_cnt = 0;
              foreach (var proto in im_addresses.get_keys ())
                {
                  var addrs_a = im_addresses.lookup (proto);

                  foreach (var addr in addrs_a)
                    {
                      var im_affl = "_:im_affl%d".printf (im_cnt);
                      var im = "_:im%d".printf (im_cnt);

                      builder.subject (im);
                      builder.predicate ("a");
                      builder.object (Trf.OntologyDefs.NCO_IMADDRESS);
                      builder.predicate (Trf.OntologyDefs.NCO_IMID);
                      builder.object_string (addr);
                      builder.predicate (Trf.OntologyDefs.NCO_IMPROTOCOL);
                      builder.object_string (proto);

                      builder.subject (im_affl);
                      builder.predicate ("a");
                      builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                      builder.predicate (Trf.OntologyDefs.NCO_HAS_IMADDRESS);
                      builder.object (im);

                      builder.subject ("_:p");
                      builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                      builder.object (im_affl);

                      im_cnt++;
                    }
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.NOTES))
            {
              var notes = (Gee.HashSet<Note>) v.get_object ();
              foreach (var n in notes)
                {
                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_NOTE);
                  builder.object_string (n.content);
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.PHONE_NUMBERS))
            {
              unowned GLib.List<FieldDetails> phone_numbers =
                (GLib.List<FieldDetails>) v.get_pointer ();

              int phone_cnt = 0;
              foreach (var p in phone_numbers)
                {
                  var phone_affl = "_:phone_affl%d".printf (phone_cnt);
                  var phone = yield this._urn_from_property (
                      Trf.OntologyDefs.NCO_PHONE,
                      Trf.OntologyDefs.NCO_PHONE_PROP, p.value);

                  if (phone == "")
                      {
                        phone = "_:phone%d".printf (phone_cnt);
                        builder.subject (phone);
                        builder.predicate ("a");
                        builder.object (Trf.OntologyDefs.NCO_PHONE);
                        builder.predicate (Trf.OntologyDefs.NCO_PHONE_PROP);
                        builder.object_string (p.value);
                      }

                  builder.subject (phone_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_PHONE);
                  builder.object (phone);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (phone_affl);

                  phone_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.ROLES))
            {
              var roles = (Gee.HashSet<Role>) v.get_object ();

              int roles_cnt = 0;
              foreach (var r in roles)
                {
                  var role_affl = "_:role_affl%d".printf (roles_cnt);

                  builder.subject (role_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_ROLE);
                  builder.object_string (r.title);
                  builder.predicate (Trf.OntologyDefs.NCO_ORG);
                  builder.object_string (r.organisation_name);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (role_affl);

                  roles_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (
                PersonaDetail.POSTAL_ADDRESSES))
            {
              unowned GLib.List<PostalAddress> postal_addresses =
                (GLib.List<PostalAddress>) v.get_pointer ();

              int postal_cnt = 0;
              foreach (var pa in postal_addresses)
                {
                  var postal_affl = "_:postal_affl%d".printf (postal_cnt);
                  var postal = "_:postal%d".printf (postal_cnt);
                  builder.subject (postal);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_POSTAL_ADDRESS);
                  builder.predicate (Trf.OntologyDefs.NCO_POBOX);
                  builder.object_string (pa.po_box);
                  builder.predicate (Trf.OntologyDefs.NCO_LOCALITY);
                  builder.object_string (pa.locality);
                  builder.predicate (Trf.OntologyDefs.NCO_POSTALCODE);
                  builder.object_string (pa.postal_code);
                  builder.predicate (Trf.OntologyDefs.NCO_STREET_ADDRESS);
                  builder.object_string (pa.street);
                  builder.predicate (Trf.OntologyDefs.NCO_EXTENDED_ADDRESS);
                  builder.object_string (pa.extension);
                  builder.predicate (Trf.OntologyDefs.NCO_COUNTRY);
                  builder.object_string (pa.country);
                  builder.predicate (Trf.OntologyDefs.NCO_REGION);
                  builder.object_string (pa.region);

                  builder.subject (postal_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS);
                  builder.object (postal);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (postal_affl);

                  postal_cnt++;
                }
            }
          else if (k == Folks.PersonaStore.detail_key (PersonaDetail.URLS))
            {
              unowned GLib.List<FieldDetails> urls =
                (GLib.List<FieldDetails>) v.get_pointer ();

              int url_cnt = 0;
              foreach (var u in urls)
                {
                  var url_affl = "_:url_affl%d".printf (url_cnt);

                  builder.subject (url_affl);
                  builder.predicate ("a");
                  builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
                  builder.predicate (Trf.OntologyDefs.NCO_URL);
                  builder.object_string (u.value);

                  builder.subject ("_:p");
                  builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
                  builder.object (url_affl);

                  url_cnt++;
                }
            }
          else
            {
              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the first parameter identifies the
                   * persona store and the second the unknown key
                   * that was received with the details params. */
                _("Unrecognized paramter %s by the  %s PersonaStore:\n')"),
                this.type_id, k);
            }
        }
      builder.insert_close ();

      Trf.Persona ret = null;
      lock (this._personas)
        {
          string? contact_urn = yield this._insert_persona (builder.result,
              "p");
          if (contact_urn != null)
            {
              string filter = " FILTER(?_contact = <%s>) ".printf (contact_urn);
              string query = this._INITIAL_QUERY.printf (filter);
              Queue<Persona> ret_personas;
              ret_personas = yield this._do_add_contacts (query);
              ret = ret_personas.pop_head ();
            }
          else
            {
              debug ("Failed to inserting the new persona  into Tracker.");
            }
        }

      return ret;
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      var urn = yield this._remove_attributes_from_persona (persona,
          _REMOVE_ALL_ATTRIBS);

      /* Finally: remove literal properties */
      var q = " DELETE { " +
        " %s ?p ?o " +
        "} " +
        "WHERE { " +
        " %s ?p ?o " +
        "} ";
      yield this._tracker_update (q.printf (urn, urn), "remove_persona");
    }

  private async string _remove_attributes_from_persona (Folks.Persona persona,
      char remove_flag)
    {
      var urn = yield this._urn_from_persona (persona);
      yield this._remove_attributes (urn, remove_flag);
      return urn;
    }

  /*
   * Garbage collecting related resources:
   *  - for each related resource we (recursively)
   *    check to if the deleted nco:Person
   *    is the only one holding a link, if so we
   *    remove the resource.
   */
  private async void _remove_attributes (string urn, char remove_flag)
    {
      Gee.HashSet<string> affiliations =
       yield this._affiliations_from_persona (urn);

     foreach (var affl in affiliations)
       {
         bool got_attrib = false;

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_PHONES) == _REMOVE_PHONES)
           {
             Gee.HashSet<string> phones =
               yield this._phones_from_affiliation (affl);

             foreach (var phone in phones)
               {
                 got_attrib = true;
                 yield this._delete_resource (phone);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_POSTALS) == _REMOVE_POSTALS)
           {
             Gee.HashSet<string> postals =
               yield this._postals_from_affiliation (affl);
             foreach (var postal in postals)
               {
                 got_attrib = true;
                 yield this._delete_resource (postal);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_IM_ADDRS) == _REMOVE_IM_ADDRS)
           {
             Gee.HashSet<string> im_addrs =
               yield this._imaddrs_from_affiliation (affl);
             foreach (var im_addr in im_addrs)
               {
                 got_attrib = true;
                 yield this._delete_resource (im_addr);
               }
           }

         if ((remove_flag & _REMOVE_ALL_ATTRIBS) ==
             _REMOVE_ALL_ATTRIBS ||
             (remove_flag & _REMOVE_EMAILS) == _REMOVE_EMAILS)
           {
             Gee.HashSet<string> emails =
               yield this._emails_from_affiliation (affl);
               foreach (var email in emails)
                 {
                   got_attrib = true;
                   yield yield this._delete_resource (email);
                 }
           }

         if (got_attrib ||
             (remove_flag & _REMOVE_ALL_ATTRIBS) == _REMOVE_ALL_ATTRIBS)
           yield this._delete_resource (affl);
       }
   }

  /**
   * Prepare the PersonaStore for use.
   *
   * TODO: we should throw different errors dependening on what went wrong
   *       when we were trying to setup the PersonaStore.
   *
   * See {@link Folks.PersonaStore.prepare}.
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              try
                {
                  this._connection =
                    yield Tracker.Sparql.Connection.get_async ();

                  yield this._build_predicates_table ();
                  yield this._do_add_contacts (this._INITIAL_QUERY.printf (""));

                  /* Don't add a match rule for all signals from Tracker but
                   * only for GraphUpdated with the specific class we need. We
                   * don't want to be woken up for irrelevent updates on the
                   * graph.
                   */
                  this._resources_object = yield GLib.Bus.get_proxy<Resources> (
                      BusType.SESSION,
                      this._OBJECT_NAME,
                      this._OBJECT_PATH,
                      DBusProxyFlags.DO_NOT_CONNECT_SIGNALS |
                        DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
                  this._resources_object.g_connection.signal_subscribe
                      (this._OBJECT_NAME, this._OBJECT_IFACE,
                      "GraphUpdated", this._OBJECT_PATH,
                      Trf.OntologyDefs.PERSON_CLASS, GLib.DBusSignalFlags.NONE,
                      this._graph_updated_cb);

                  this._is_prepared = true;
                  this.notify_property ("is-prepared");
                }
              catch (GLib.IOError e1)
                {
                  warning ("Could not connect to D-Bus service: %s",
                           e1.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e1.message);
                }
              catch (Tracker.Sparql.Error e2)
                {
                  warning ("Error fetching SPARQL connection handler: %s",
                           e2.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e2.message);
                }
              catch (GLib.DBusError e3)
                {
                  warning ("Could not connect to D-Bus service: %s",
                           e3.message);
                  throw new PersonaStoreError.INVALID_ARGUMENT (e3.message);
                }
            }
        }
    }

  public int get_favorite_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_FAVORITE);
    }

  public int get_gender_male_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_MALE);
    }

  public int get_gender_female_id ()
    {
      return this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_FEMALE);
    }

  private async void _build_predicates_table ()
    {
      if (this._prefix_tracker_id != null)
        {
          return;
        }

      yield this._build_urn_prefix_table ();

      this._prefix_tracker_id = new Gee.TreeMap<string, int> ();

      string query = "SELECT  ";
      foreach (var urn_t in this._urn_prefix.keys)
        {
          query += " tracker:id(" + urn_t + ")";
        }
      query += " WHERE {} ";

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);

          while (cursor.next ())
            {
              int i=0;
              foreach (var urn in this._urn_prefix.keys)
                {
                  var tracker_id = (int) cursor.get_integer (i);
                  var prefix = this._urn_prefix.get (urn).dup ();
                  this._prefix_tracker_id.set (prefix, tracker_id);
                  i++;
                }
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't build predicates table: %s %s", query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't build predicates table: %s %s", query, e2.message);
        }
    }

  private async void _build_urn_prefix_table ()
    {
      if (this._urn_prefix != null)
        {
          return;
        }
      this._urn_prefix = new Gee.TreeMap<string, string> ();
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#fullname>",
          Trf.OntologyDefs.NCO_FULLNAME);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameFamily>",
          Trf.OntologyDefs.NCO_FAMILY);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameGiven>",
          Trf.OntologyDefs.NCO_GIVEN);
      this._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameAdditional>",
          Trf.OntologyDefs.NCO_ADDITIONAL);
      this._urn_prefix.set (
          Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificSuffix>",
          Trf.OntologyDefs.NCO_SUFFIX);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nameHonorificPrefix>",
         Trf.OntologyDefs.NCO_PREFIX);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#nickname>",
         Trf.OntologyDefs.NCO_NICKNAME);
      this._urn_prefix.set (
         Trf.OntologyDefs.RDF_URL_PREFIX + "22-rdf-syntax-ns#type>",
         Trf.OntologyDefs.RDF_TYPE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#PersonContact>",
         Trf.OntologyDefs.NCO_PERSON);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#websiteUrl>",
         Trf.OntologyDefs.NCO_WEBSITE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#blogUrl>",
         Trf.OntologyDefs.NCO_BLOG);
      this._urn_prefix.set (
         Trf.OntologyDefs.NAO_URL_PREFIX + "nao#predefined-tag-favorite>",
         Trf.OntologyDefs.NAO_FAVORITE);
      this._urn_prefix.set (Trf.OntologyDefs.NAO_URL_PREFIX + "nao#hasTag>",
         Trf.OntologyDefs.NAO_TAG);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasEmailAddress>",
         Trf.OntologyDefs.NCO_HAS_EMAIL);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasPhoneNumber>",
         Trf.OntologyDefs.NCO_HAS_PHONE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#hasAffiliation>",
         Trf.OntologyDefs.NCO_HAS_AFFILIATION);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#birthDate>",
         Trf.OntologyDefs.NCO_BIRTHDAY);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#note>",
         Trf.OntologyDefs.NCO_NOTE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender>",
         Trf.OntologyDefs.NCO_GENDER);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-male>",
         Trf.OntologyDefs.NCO_MALE);
      this._urn_prefix.set (
         Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-female>",
         Trf.OntologyDefs.NCO_FEMALE);
      this._urn_prefix.set (Trf.OntologyDefs.NCO_URL_PREFIX + "nco#photo>",
         Trf.OntologyDefs.NCO_PHOTO);
    }

  private void _graph_updated_cb (DBusConnection connection,
      string sender_name, string object_path, string interface_name,
      string signal_name, Variant parameters)
    {
      string class_name = "";
      VariantIter iter_del = null;
      VariantIter iter_ins = null;

      parameters.get("(sa(iiii)a(iiii))", &class_name, &iter_del, &iter_ins);

      if (class_name != Trf.OntologyDefs.PERSON_CLASS)
        {
          return;
        }

      this._handle_events ((owned) iter_del, (owned) iter_ins);
    }

  private async void _handle_events
      (owned VariantIter iter_del, owned VariantIter iter_ins)
    {
      yield this._handle_delete_events ((owned) iter_del);
      yield this._handle_insert_events ((owned) iter_ins);
    }

  private async void _handle_delete_events (owned VariantIter iter_del)
    {
      var removed_personas = new Queue<Persona> ();
      var nco_person_id =
          this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_PERSON);
      var rdf_type_id = this._prefix_tracker_id.get (Trf.OntologyDefs.RDF_TYPE);
      Event e = Event ();

      while (iter_del.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var p_id = Trf.Persona.build_iid (this.id, e.subject_id.to_string ());
          if (e.pred_id == rdf_type_id &&
              e.object_id == nco_person_id)
            {
              lock (this._personas)
                {
                  var removed_p = this._personas.lookup (p_id);
                  if (removed_p != null)
                    {
                      removed_personas.push_tail (removed_p);
                      _personas.remove (removed_p.iid);
                    }
                }
            }
          else
            {
              var persona = this._personas.lookup (p_id);
              if (persona != null)
                {
                  yield this._do_update (persona, e, false);
                }
            }
        }

      if (removed_personas.length > 0)
        {
          this.personas_changed (null, removed_personas.head, null, null, 0);
        }
    }

  private async void _handle_insert_events (owned VariantIter iter_ins)
    {
      var added_personas = new Queue<Persona> ();
      Event e = Event ();

      while (iter_ins.next
          ("(iiii)", &e.graph_id, &e.subject_id, &e.pred_id, &e.object_id))
        {
          var subject_tracker_id = e.subject_id.to_string ();
          var p_id = Trf.Persona.build_iid (this.id, subject_tracker_id);
          Trf.Persona persona;
          lock (this._personas)
            {
              persona = this._personas.lookup (p_id);
              if (persona == null)
                {
                  persona = new Trf.Persona (this, subject_tracker_id);
                  this._personas.insert (persona.iid, persona);
                  added_personas.push_tail (persona);
                }
            }
          yield this._do_update (persona, e);
        }

      if (added_personas.length > 0)
        {
          this.personas_changed (added_personas.head, null, null, null, 0);
        }
    }

  private async Queue<Persona> _do_add_contacts (string query)
    {
      var added_personas = new Queue<Persona> ();

     try {
        Sparql.Cursor cursor = yield this._connection.query_async (query);

        while (cursor.next ())
          {
            int tracker_id = (int) cursor.get_integer (Trf.Fields.TRACKER_ID);
            var p_id = Trf.Persona.build_iid (this.id, tracker_id.to_string ());
            if (this._personas.lookup (p_id) == null)
              {
                var persona = new Trf.Persona (this,
                    tracker_id.to_string (), cursor);
                this._personas.insert (persona.iid, persona);
                added_personas.push_tail (persona);
              }
          }

        if (added_personas.length > 0)
          {
            this.personas_changed (added_personas.head, null, null, null, 0);
          }
      } catch (GLib.Error e) {
        warning ("Couldn't perform queries: %s %s", query, e.message);
      }

      return added_personas;
    }

  private async void _do_update (Persona p, Event e, bool adding = true)
    {
      if (e.pred_id ==
          this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FULLNAME))
        {
          string fullname = "";
          if (adding)
            {
              fullname =
                yield this._get_property (e.subject_id,
                    Trf.OntologyDefs.NCO_FULLNAME);
            }
          p._update_full_name (fullname);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_NICKNAME))
        {
          string alias = "";
          if (adding)
            {
              alias =
                yield this._get_property (
                    e.subject_id, Trf.OntologyDefs.NCO_NICKNAME);
            }
          p._update_alias (alias);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_FAMILY))
        {
          string family_name = "";
          if (adding)
            {
              family_name = yield this._get_property (e.subject_id,
                  Trf.OntologyDefs.NCO_FAMILY);
            }
          p._update_family_name (family_name);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_GIVEN))
        {
          string given_name = "";
          if (adding)
            {
              given_name = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_GIVEN);
            }
          p._update_given_name (given_name);
        }
      else if (e.pred_id ==
               this._prefix_tracker_id.get (Trf.OntologyDefs.NCO_ADDITIONAL))
        {
          string additional_name = "";
          if (adding)
            {
              additional_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_ADDITIONAL);
            }
          p._update_additional_names (additional_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_SUFFIX))
        {
          string suffix_name = "";
          if (adding)
            {
              suffix_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_SUFFIX);
            }
          p._update_suffixes (suffix_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PREFIX))
        {
          string prefix_name = "";
          if (adding)
            {
              prefix_name = yield this._get_property
                  (e.subject_id, Trf.OntologyDefs.NCO_PREFIX);
            }
          p._update_prefixes (prefix_name);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NAO_TAG))
        {
          if (e.object_id == this.get_favorite_id ())
            {
              if (adding)
                {
                  p._set_favourite (true);
                }
              else
                {
                  p._set_favourite (false);
                }
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_EMAIL))
        {
          if (adding)
            {
              var email = yield this._get_property (
                  e.object_id,
                  Trf.OntologyDefs.NCO_EMAIL_PROP,
                  Trf.OntologyDefs.NCO_EMAIL);
              p._add_email (email, e.object_id.to_string ());
            }
          else
            {
              p._remove_email (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_PHONE))
        {
          if (adding)
            {
              var phone = yield this._get_property (
                  e.object_id, Trf.OntologyDefs.NCO_PHONE_PROP,
                  Trf.OntologyDefs.NCO_PHONE);
              p._add_phone (phone, e.object_id.to_string ());
            }
          else
            {
              p._remove_phone (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_HAS_AFFILIATION))
        {
          if (adding)
            {
              var affl_info =
                yield this._get_affl_info (e.subject_id.to_string (),
                  e.object_id.to_string ());

              debug ("affl_info : %s", affl_info.to_string ());

              if (affl_info.im_tracker_id != null)
                {
                  p._update_nickname (affl_info.im_nickname);
                  if (affl_info.im_proto != null)
                    p._add_im_address (affl_info.affl_tracker_id,
                        affl_info.im_proto, affl_info.im_account_id);
                }

              if (affl_info.affl_tracker_id != null)
                {
                  if (affl_info.title != null ||
                      affl_info.org != null)
                    {
                      p._add_role (affl_info.affl_tracker_id, affl_info.title,
                          affl_info.org);
                    }
                }

              if (affl_info.postal_address != null)
                p._add_postal_address (affl_info.postal_address);

              if (affl_info.phone != null)
                p._add_phone (affl_info.phone, e.object_id.to_string ());

              if (affl_info.email != null)
                p._add_email (affl_info.email, e.object_id.to_string ());

              if (affl_info.website != null)
                p._add_url (affl_info.website,
                    affl_info.affl_tracker_id, "website");

              if (affl_info.blog != null)
                p._add_url (affl_info.blog,
                    affl_info.affl_tracker_id, "blog");

              if (affl_info.url != null)
                p._add_url (affl_info.url,
                    affl_info.affl_tracker_id, "url");
            }
          else
            {
              p._remove_im_address (e.object_id.to_string ());
              p._remove_role (e.object_id.to_string ());
              p._remove_postal_address (e.object_id.to_string ());
              p._remove_phone (e.object_id.to_string ());
              p._remove_email (e.object_id.to_string ());
              p._remove_url (e.object_id.to_string ());
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_BIRTHDAY))
        {
          string bday = "";
          if (adding)
            {
              bday = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_BIRTHDAY);
            }
          p._set_birthday (bday);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_NOTE))
        {
          string note = "";
          if (adding)
            {
              note = yield this._get_property (
                  e.subject_id, Trf.OntologyDefs.NCO_NOTE);
            }
          p._set_note (note);
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_GENDER))
        {
          if (adding)
            {
              p._set_gender (e.object_id);
            }
          else
            {
              p._set_gender (0);
            }
        }
      else if (e.pred_id == this._prefix_tracker_id.get
          (Trf.OntologyDefs.NCO_PHOTO))
        {
          string avatar_url = "";
          if (adding)
            {
              avatar_url = yield this._get_property (e.object_id,
                  Trf.OntologyDefs.NIE_URL, Trf.OntologyDefs.NFO_IMAGE);
            }
          p._set_avatar (avatar_url);
        }
    }

  private async string _get_property
      (int subject_tracker_id, string property,
       string subject_type = Trf.OntologyDefs.NCO_PERSON)
    {
      const string query_template =
        "SELECT ?property WHERE" +
        " { ?p a %s ; " +
        "   %s ?property " +
        " . FILTER(tracker:id(?p) = %d ) }";

      string query = query_template.printf (subject_type,
          property, subject_tracker_id);
      return yield this._single_value_query (query);
    }

  /*
   * This should be kept in sync with Trf.AfflInfoFields
   */
  private async Trf.AfflInfo _get_affl_info (
      string person_id, string affiliation_id)
    {
      Trf.AfflInfo affl_info = new Trf.AfflInfo ();
      const string query_template =
        "SELECT " +
        "tracker:id(?i) " +
        Trf.OntologyDefs.NCO_IMPROTOCOL  + "(?i) " +
        Trf.OntologyDefs.NCO_IMID + "(?i) " +
        "tracker:id(?a) " +
        Trf.OntologyDefs.NCO_ROLE + "(?a) " +
        Trf.OntologyDefs.NCO_ORG + "(?a) " +
        Trf.OntologyDefs.NCO_POBOX + "(?postal) " +
        Trf.OntologyDefs.NCO_DISTRICT + "(?postal) " +
        Trf.OntologyDefs.NCO_COUNTY + "(?postal) " +
        Trf.OntologyDefs.NCO_LOCALITY + "(?postal) " +
        Trf.OntologyDefs.NCO_POSTALCODE + "(?postal) " +
        Trf.OntologyDefs.NCO_STREET_ADDRESS + "(?postal) " +
        Trf.OntologyDefs.NCO_ADDRESS_LOCATION + "(?postal) " +
        Trf.OntologyDefs.NCO_EXTENDED_ADDRESS + "(?postal) " +
        Trf.OntologyDefs.NCO_COUNTRY + "(?postal) " +
        Trf.OntologyDefs.NCO_REGION + "(?postal) " +
        Trf.OntologyDefs.NCO_EMAIL_PROP + "(?e) " +
        Trf.OntologyDefs.NCO_PHONE_PROP + "(?number) " +
        Trf.OntologyDefs.NCO_WEBSITE + "(?a) " +
        Trf.OntologyDefs.NCO_BLOG + "(?a) " +
        Trf.OntologyDefs.NCO_URL + "(?a) " +
        Trf.OntologyDefs.NCO_IM_NICKNAME + "(?i) " +
        "WHERE { "+
        " ?p a " + Trf.OntologyDefs.NCO_PERSON  + " ; " +
        Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_IMADDRESS + " ?i } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS +
        "               ?postal } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_EMAIL + " ?e } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_HAS_PHONE + " ?number }  " +
        " FILTER(tracker:id(?p) = %s" +
        " && tracker:id(?a) = %s" +
        " ) } ";

      string query = query_template.printf (person_id, affiliation_id);

      debug ("_get_affl_info: %s", query);

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);
          while (yield cursor.next_async ())
            {
              affl_info.im_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_TRACKER_ID).dup ();
              affl_info.im_proto = cursor.get_string
                  (Trf.AfflInfoFields.IM_PROTOCOL).dup ();
              affl_info.im_account_id = cursor.get_string
                  (Trf.AfflInfoFields.IM_ACCOUNT_ID).dup ();
              affl_info.im_nickname = cursor.get_string
                  (Trf.AfflInfoFields.IM_NICKNAME).dup ();

              affl_info.affl_tracker_id = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_TRACKER_ID).dup ();
              affl_info.title = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ROLE).dup ();
              affl_info.org = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_ORG).dup ();

              var po_box = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_POBOX).dup ();
              var extension = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_EXTENDED_ADDRESS).dup ();
              var street = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_STREET_ADDRESS).dup ();
              var locality = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_LOCALITY).dup ();
              var region = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_REGION).dup ();
              var postal_code = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_POSTALCODE).dup ();
              var country = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_COUNTRY).dup ();

              List<string> types = new List<string> ();

              affl_info.postal_address = new Folks.PostalAddress (
                  po_box, extension, street, locality, region, postal_code,
                  country, null, (owned) types, affl_info.affl_tracker_id);

              affl_info.email = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_EMAIL).dup ();
              affl_info.phone = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_PHONE).dup ();

              affl_info.website = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_WEBSITE).dup ();
              affl_info.blog = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_BLOG).dup ();
              affl_info.url = cursor.get_string
                  (Trf.AfflInfoFields.AFFL_URL).dup ();
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't fetch affiliation info: %s %s",
              query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't fetch affiliation info: %s %s",
              query, e2.message);
        }

      return affl_info;
    }

  private async string? _insert_persona (string query, string persona_var)
    {
      GLib.Variant variant;
      string contact_urn = null;

      try
        {
          debug ("_insert_persona: %s", query);
          variant = yield this._connection.update_blank_async (query);

          VariantIter iter1, iter2, iter3;
          string anon_var = null;
          iter1 = variant.iterator ();

          while (iter1.next ("aa{ss}", out iter2))
            {
              if (iter2 == null)
                continue;

              while (iter2.next ("a{ss}", out iter3))
                {
                  if (iter3 == null)
                    continue;

                  while (iter3.next ("{ss}", out anon_var, out contact_urn))
                    {
                      /* The dictionary mapping blank node names to
                       * IRIs doesn't have a fixed order so we need
                       * check for the anon var corresponding to
                       * nco:PersonContact.
                       */
                      if (anon_var == persona_var)
                        return contact_urn;
                    }
                }
            }
        }
      catch (GLib.Error e)
        {
          contact_urn = null;
          warning ("Couldn't insert nco:PersonContact: %s", e.message);
        }

      return null;
    }

  private async string _single_value_query (string query)
    {
      Gee.HashSet<string> rows = yield this._multi_value_query (query);
      foreach (var r in rows)
        {
          return r;
        }
      return "";
    }

  private async Gee.HashSet<string> _multi_value_query (string query)
    {
      Gee.HashSet<string> ret = new Gee.HashSet<string> ();

      try
        {
          Sparql.Cursor cursor = yield this._connection.query_async (query);
          while (cursor.next ())
            {
              var prop = cursor.get_string (0);
              if (prop != null)
                ret.add (prop);
            }
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("Couldn't run query: %s %s", query, e1.message);
        }
      catch (GLib.Error e2)
        {
          warning ("Couldn't run query: %s %s", query, e2.message);
        }

      return ret;
    }

  private async string _urn_from_tracker_id (string tracker_id)
    {
      const string query = "SELECT fn:concat('<', tracker:uri(%s), '>') " +
        "WHERE {}";
      return yield this._single_value_query (query.printf (tracker_id));
    }

  internal async void _set_alias (Trf.Persona persona, string alias)
    {
      const string query_t = "DELETE { "+
        " ?p " + Trf.OntologyDefs.NCO_NICKNAME + " ?n  " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NCO_NICKNAME + " ?n . " +
        " FILTER(tracker:id(?p) = %s) " +
        "} " +
        "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_NICKNAME + " '%s' " +
        "} " +
        "WHERE { "+
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        "FILTER (tracker:id(?p) = %s) " +
        "} ";

      string query = query_t.printf (persona.tracker_id (), alias,
          persona.tracker_id ());

      yield this._tracker_update (query, "change_alias");
    }

  internal async void _set_is_favourite (Folks.Persona persona,
      bool is_favourite)
    {
      const string ins_q = "INSERT { " +
        " ?p " + Trf.OntologyDefs.NAO_TAG + " " +
        Trf.OntologyDefs.NAO_FAVORITE +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      const string del_q = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NAO_TAG + " " +
        Trf.OntologyDefs.NAO_FAVORITE + " " +
       "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      string query;

      if (is_favourite)
        {
          query = ins_q.printf (((Trf.Persona) persona).tracker_id ());
        }
      else
        {
          query = del_q.printf (((Trf.Persona) persona).tracker_id ());
        }

      yield this._tracker_update (query, "change_is_favourite");
    }

  internal async void _set_phones (Folks.Persona persona,
      owned GLib.List<FieldDetails> phone_numbers)
    {
      yield this._set_attrib (persona, (owned) phone_numbers,
          Trf.Attrib.PHONES);
    }

  internal async void _set_emails (Folks.Persona persona,
      owned GLib.List<FieldDetails> emails)
    {
      yield this._set_attrib (persona, (owned) emails,
          Trf.Attrib.EMAILS);
    }

  internal async void _set_urls (Folks.Persona persona,
      owned GLib.List<FieldDetails> urls)
    {
       yield this._set_attrib (persona, (owned) urls,
          Trf.Attrib.URLS);
    }

  internal async void _set_im_addresses (Folks.Persona persona,
      owned HashTable<string, LinkedHashSet<string>> im_addresses)
    {
      /* FIXME:
       * - this conversion should go away once we've switched to use the
       *   same data structure for each property that is a list of something.
       *   See: https://bugzilla.gnome.org/show_bug.cgi?id=646079 */
      GLib.List <FieldDetails> ims = new GLib.List <FieldDetails> ();
      foreach (var proto in im_addresses.get_keys ())
        {
          var addrs = im_addresses.lookup (proto);
          foreach (var a in addrs)
            {
              var fd = new FieldDetails (a);
              fd.set_parameter ("proto", proto);
              ims.prepend ((owned) fd);
            }
        }

       yield this._set_attrib (persona, (owned) ims,
          Trf.Attrib.IM_ADDRESSES);
    }

  internal async void _set_postal_addresses (Folks.Persona persona,
      owned GLib.List<PostalAddress> postal_addresses)
    {
       yield this._set_attrib (persona, (owned) postal_addresses,
          Trf.Attrib.POSTAL_ADDRESSES);
    }

  internal async void _set_roles (Folks.Persona persona,
      owned Gee.HashSet<Role> roles)
    {
      const string del_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + "; " +
        " " + Trf.OntologyDefs.NCO_HAS_AFFILIATION + " ?a . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_ORG +  " ?o } . " +
        " OPTIONAL { ?a " + Trf.OntologyDefs.NCO_ROLE + " ?r } . " +
        " FILTER(tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      string del_q = del_t.printf (p_id);

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);

      int i = 0;
      foreach (var r in roles)
        {
          string affl = "_:a%d".printf (i);

          builder.subject (affl);
          builder.predicate ("a");
          builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
          builder.predicate (Trf.OntologyDefs.NCO_ROLE);
          builder.object_string (r.title);
          builder.predicate (Trf.OntologyDefs.NCO_ORG);
          builder.object_string (r.organisation_name);
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
          builder.object (affl);
        }

      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (del_q + builder.result, "_set_roles");
   }

  internal async void _set_notes (Folks.Persona persona,
      owned Gee.HashSet<Note> notes)
    {
      const string del_t = "DELETE { " +
        "?p " + Trf.OntologyDefs.NCO_NOTE  + " ?n " +
        "} " +
        "WHERE {" +
        " ?p a nco:PersonContact ; " +
        Trf.OntologyDefs.NCO_NOTE + " ?n . " +
        " FILTER(tracker:id(?p) = %s)" +
        "}";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      string del_q = del_t.printf (p_id);

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);

      foreach (var n in notes)
        {
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_NOTE);
          builder.object_string (n.content);
        }

      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (del_q + builder.result, "_set_notes");
    }

  internal async void _set_birthday (Folks.Persona persona,
      owned DateTime bday)
    {
      const string q_t = "DELETE { " +
         " ?p " + Trf.OntologyDefs.NCO_BIRTHDAY + " ?b " +
         "} " +
         "WHERE { " +
         " ?p a " + Trf.OntologyDefs.NCO_PERSON + "; " +
         Trf.OntologyDefs.NCO_BIRTHDAY + " ?b . " +
         " FILTER (tracker:id(?p) = %s ) " +
         "} " +
         "INSERT { " +
         " ?p " + Trf.OntologyDefs.NCO_BIRTHDAY + " '%s' " +
         "} " +
         "WHERE { " +
         " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
         " FILTER (tracker:id(?p) = %s) " +
         "} ";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      TimeVal tv;
      bday.to_timeval (out tv);
      string query = q_t.printf (p_id, tv.to_iso8601 (), p_id);

      yield this._tracker_update (query, "_set_birthday");
    }

  internal async void _set_gender (Folks.Persona persona,
      owned Gender gender)
    {
      const string del_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_GENDER + " ?g " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " ; " +
        Trf.OntologyDefs.NCO_GENDER + " ?g . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";
      const string ins_t = "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_GENDER + " %s " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON +  " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      string query;

      if (gender == Gender.UNSPECIFIED)
        {
          query = del_t.printf (p_id);
        }
      else
        {
          string gender_urn;

          if (gender == Gender.MALE)
            gender_urn = Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-male>";
          else
            gender_urn = Trf.OntologyDefs.NCO_URL_PREFIX + "nco#gender-female>";

          query = del_t.printf (p_id) + ins_t.printf (gender_urn, p_id);
        }

      yield this._tracker_update (query, "_set_gender");
    }

  internal async void _set_avatar (Folks.Persona persona,
      File avatar)
    {
      const string query_t = "DELETE {" +
        " ?c " + Trf.OntologyDefs.NCO_PHOTO  + " ?p " +
        " } " +
        "WHERE { " +
        " ?c a " + Trf.OntologyDefs.NCO_PERSON  + " ; " +
        Trf.OntologyDefs.NCO_PHOTO + " ?p . " +
        " FILTER(tracker:id(?c) = %s) " +
        "} " +
        "INSERT { " +
        " _:i a " + Trf.OntologyDefs.NFO_IMAGE  + ", " +
        Trf.OntologyDefs.NIE_DATAOBJECT + " ; " +
        Trf.OntologyDefs.NIE_URL + " '%s' . " +
        " ?c " + Trf.OntologyDefs.NCO_PHOTO + " _:i " +
        "} " +
        "WHERE { " +
        " ?c a nco:PersonContact . " +
        " FILTER(tracker:id(?c) = %s) " +
        "}";

      var p_id = ((Trf.Persona) persona).tracker_id ();

      var image_urn = yield this._get_property (int.parse (p_id),
          Trf.OntologyDefs.NCO_PHOTO);
      if (image_urn != "")
        this._delete_resource ("<%s>".printf (image_urn));

      string query = query_t.printf (p_id, avatar.get_uri (), p_id);
      yield this._tracker_update (query, "_set_avatar");
    }

  internal async void _set_structured_name (Folks.Persona persona,
      StructuredName sname)
    {
      const string query_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_FAMILY + " ?family . " +
        " ?p " + Trf.OntologyDefs.NCO_GIVEN + " ?given . " +
        " ?p " + Trf.OntologyDefs.NCO_ADDITIONAL + " ?adi . " +
        " ?p " + Trf.OntologyDefs.NCO_PREFIX + " ?prefix . " +
        " ?p " + Trf.OntologyDefs.NCO_SUFFIX + " ?suffix " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " .  " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_FAMILY + " ?family } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_GIVEN + " ?given } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_ADDITIONAL + " ?adi } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_PREFIX + " ?prefix } . " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_SUFFIX + " ?suffix } . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} " +
        "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_FAMILY + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_GIVEN + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_ADDITIONAL + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_PREFIX + " '%s'; " +
        " " + Trf.OntologyDefs.NCO_SUFFIX + " '%s' " +
        " } " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      string query = query_t.printf (p_id, sname.family_name, sname.given_name,
          sname.additional_names, sname.prefixes, sname.suffixes, p_id);
      yield this._tracker_update (query, "_set_structured_name");
    }

  internal async void _set_full_name  (Folks.Persona persona,
      string full_name)
    {
      const string query_t = "DELETE { " +
        " ?p " + Trf.OntologyDefs.NCO_FULLNAME + " ?fn " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " .  " +
        " OPTIONAL { ?p " + Trf.OntologyDefs.NCO_FULLNAME + " ?fn } . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} " +
        "INSERT { " +
        " ?p " + Trf.OntologyDefs.NCO_FULLNAME + " '%s' " +
        "} " +
        "WHERE { " +
        " ?p a " + Trf.OntologyDefs.NCO_PERSON + " . " +
        " FILTER (tracker:id(?p) = %s) " +
        "} ";

      var p_id = ((Trf.Persona) persona).tracker_id ();
      string query = query_t.printf (p_id, full_name, p_id);
      yield this._tracker_update (query, "_set_full_name");
    }

  /* NOTE:
   * - first we nuke old attribs
   * - we create new affls with the new attribs
   */
  private async void _set_attrib (Folks.Persona persona,
      owned GLib.List<Object> attribs, Trf.Attrib what)
    {
      var p_id = ((Trf.Persona) persona).tracker_id ();

      unowned string? related_attrib = null;
      unowned string? related_prop = null;
      unowned string? related_prop_2 = null;
      unowned string? related_connection = null;

      switch (what)
        {
          case Trf.Attrib.PHONES:
            related_attrib = Trf.OntologyDefs.NCO_PHONE;
            related_prop = Trf.OntologyDefs.NCO_PHONE_PROP;
            related_connection = Trf.OntologyDefs.NCO_HAS_PHONE;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_PHONES);
            break;
          case Trf.Attrib.EMAILS:
            related_attrib = Trf.OntologyDefs.NCO_EMAIL;
            related_prop = Trf.OntologyDefs.NCO_EMAIL_PROP;
            related_connection = Trf.OntologyDefs.NCO_HAS_EMAIL;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_EMAILS);
            break;
          case Trf.Attrib.URLS:
            related_attrib = Trf.OntologyDefs.NCO_URL;
            related_connection = Trf.OntologyDefs.NCO_URL;
            break;
          case Trf.Attrib.IM_ADDRESSES:
            related_attrib = Trf.OntologyDefs.NCO_IMADDRESS;
            related_prop = Trf.OntologyDefs.NCO_IMID;
            related_prop_2 = Trf.OntologyDefs.NCO_IMPROTOCOL;
            related_connection = Trf.OntologyDefs.NCO_HAS_IMADDRESS;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_IM_ADDRS);
            break;
          case Trf.Attrib.POSTAL_ADDRESSES:
            related_attrib = Trf.OntologyDefs.NCO_POSTAL_ADDRESS;
            related_connection = Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS;
            yield this._remove_attributes_from_persona (persona,
                _REMOVE_POSTALS);
            break;
        }

      var builder = new Tracker.Sparql.Builder.update ();
      builder.insert_open (null);
      int i = 0;
      foreach (var p in attribs)
        {
          FieldDetails fd = null;
          PostalAddress pa = null;

          string affl = "_:a%d".printf (i);
          string attr;

          if (what == Trf.Attrib.POSTAL_ADDRESSES)
            {
              pa = (PostalAddress) p;
              attr = "_:p%d".printf (i);
              builder.subject (attr);
              builder.predicate ("a");
              builder.object (related_attrib);
              builder.predicate (Trf.OntologyDefs.NCO_POBOX);
              builder.object_string (pa.po_box);
              builder.predicate (Trf.OntologyDefs.NCO_LOCALITY);
              builder.object_string (pa.locality);
              builder.predicate (Trf.OntologyDefs.NCO_POSTALCODE);
              builder.object_string (pa.postal_code);
              builder.predicate (Trf.OntologyDefs.NCO_STREET_ADDRESS);
              builder.object_string (pa.street);
              builder.predicate (Trf.OntologyDefs.NCO_EXTENDED_ADDRESS);
              builder.object_string (pa.extension);
              builder.predicate (Trf.OntologyDefs.NCO_COUNTRY);
              builder.object_string (pa.country);
              builder.predicate (Trf.OntologyDefs.NCO_REGION);
              builder.object_string (pa.region);
            }
          else if (what == Trf.Attrib.URLS)
            {
              fd = (FieldDetails) p;
              unowned List<string> type_p = fd.get_parameter_values ("type");
              if (type_p.length () > 0)
                {
                  if (type_p.nth_data (0) == "blog")
                    {
                      related_connection = Trf.OntologyDefs.NCO_BLOG;
                    }
                  else if (type_p.nth_data (0) == "website")
                    {
                      related_connection = Trf.OntologyDefs.NCO_WEBSITE;
                    }
                }
              attr = "'%s'".printf (fd.value);
            }
          else
            {
              fd = (FieldDetails) p;
              attr = "_:p%d".printf (i);
              builder.subject (attr);
              builder.predicate ("a");
              builder.object (related_attrib);
              builder.predicate (related_prop);
              builder.object_string (fd.value);

              if (what == Trf.Attrib.IM_ADDRESSES)
                {
                  builder.predicate (related_prop_2);
                  unowned List<string> im_params =
                      fd.get_parameter_values ("proto");
                  builder.object_string (im_params.nth_data (0));
                }
            }

          builder.subject (affl);
          builder.predicate ("a");
          builder.object (Trf.OntologyDefs.NCO_AFFILIATION);
          builder.predicate (related_connection);
          builder.object (attr);
          builder.subject ("?contact");
          builder.predicate (Trf.OntologyDefs.NCO_HAS_AFFILIATION);
          builder.object (affl);

          i++;
        }
      builder.insert_close ();
      builder.where_open ();
      builder.subject ("?contact");
      builder.predicate ("a");
      builder.object (Trf.OntologyDefs.NCO_PERSON);
      string filter = " FILTER(tracker:id(?contact) = %s) ".printf (p_id);
      builder.append (filter);
      builder.where_close ();

      yield this._tracker_update (builder.result, "set_attrib");
    }

  private async bool _tracker_update (string query, string caller)
    {
      bool ret = false;

      debug ("%s: %s", caller, query);

      try
        {
          yield this._connection.update_async (query);
          ret = true;
        }
      catch (Tracker.Sparql.Error e1)
        {
          warning ("[%s] SPARQL syntax error: %s. Query: %s",
              caller, e1.message, query);
        }
      catch (GLib.IOError e2)
        {
          warning ("[%s] IO error: %s",
              caller, e2.message);
        }
      catch (GLib.DBusError e3)
        {
          warning ("[%s] DBus error: %s",
              caller, e3.message);
        }

      return ret;
    }

  private async Gee.HashSet<string> _affiliations_from_persona (string urn)
    {
      return yield this._linked_resources (urn, Trf.OntologyDefs.NCO_PERSON,
          Trf.OntologyDefs.NCO_HAS_AFFILIATION);
    }

  private async Gee.HashSet<string> _phones_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_PHONE);
    }

  private async Gee.HashSet<string>  _postals_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_POSTAL_ADDRESS);
    }

  private async Gee.HashSet<string> _imaddrs_from_affiliation  (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_IMADDRESS);
    }

  private async Gee.HashSet<string> _emails_from_affiliation (string affl)
    {
      return yield this._linked_resources (affl,
          Trf.OntologyDefs.NCO_AFFILIATION,
          Trf.OntologyDefs.NCO_HAS_EMAIL);
    }

  /**
   * Retrieve the list of linked resources of a given subject
   *
   * @param resource          the urn of the resource in <urn> format
   * @return number of resources linking to this resource
   */
  private async int _resource_usage_count (string resource)
    {
      const string query_t = "SELECT " +
        " count(?s) " +
        "WHERE { " +
        " %s a rdfs:Resource . " +
        " ?s ?p %s } ";

      var query = query_t.printf (resource, resource);
      var result = yield this._single_value_query (query);
      return int.parse (result);
    }

  /*
   * NOTE:
   *
   * We asume that the caller is holding a link to the resource,
   * so if _resource_usage_count () == 1 it means no one else
   * (beside the caller) is linking to the resource.
   *
   * This means that _delete_resource shold be called before
   * removing the resources that hold a link to it (which also
   * makes sense from the signaling perspective).
   */
  private async bool _delete_resource (string resource_urn,
      bool check_count = true)
    {
      bool deleted = false;
      var query_t = " DELETE { " +
        " %s a rdfs:Resource " +
        "} " +
        "WHERE { " +
        " %s a rdfs:Resource " +
        "} ";

      var query = query_t.printf (resource_urn, resource_urn);
      if (check_count)
        {
          int count = yield this._resource_usage_count (resource_urn);
          if (count == 1)
            {
              deleted = yield this._tracker_update (query, "_delete_resource");
            }
        }
      else
        {
          deleted = yield this._tracker_update (query, "_delete_resource");
        }

      return deleted;
    }

  /**
   * Retrieve the list of linked resources of a given subject
   *
   * @param urn               the urn of the subject in <urn> format
   * @param subject_type      i.e: nco:Person, nco:Affiliation, etc
   * @param linking_predicate i.e.: nco:hasAffiliation
   * @return a list of linked resources (in <urn> format)
   */
  private async Gee.HashSet<string> _linked_resources (string urn,
      string subject_type, string linking_predicate)
    {
      string query_t = "SELECT " +
        " fn:concat('<',?linkedr,'>')  " +
        "WHERE { " +
        " %s a %s; " +
        " %s ?linkedr " +
        "} ";

      var query = query_t.printf (urn, subject_type, linking_predicate);
      return yield this._multi_value_query (query);
    }

  private async string _urn_from_persona (Folks.Persona persona)
    {
      var id = ((Trf.Persona) persona).tracker_id ();
      return yield this._urn_from_tracker_id (id);
    }

  /**
   * Helper method to figure out if a constrained property
   * already exists.
   */
  private async string _urn_from_property (string class_name,
      string property_name,
      string property_value)
    {
      const string query_template = "SELECT " +
        " fn:concat('<', ?o, '>') " +
        "WHERE { " +
        " ?o a %s ; " +
        " %s ?prop_val . " +
        "FILTER (?prop_val = '%s') " +
        "}";

      string query = query_template.printf (class_name,
          property_name, property_value);
      return yield this._single_value_query (query);
    }
}
