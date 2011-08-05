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

using E;
using Folks;
using Random;

errordomain EdsTest.BackendSetupError
{
  FETCH_SOURCE_GROUP_FAILED,
  OPENING_FAILED,
  ADD_CONTACT_FAILED,
  ADD_TO_SOURCE_GROUP_FAILED,
}

public class EdsTest.Backend
{
  public const string address_book_uri = "local://test";
  private string _addressbook_name;
  private E.BookClient _addressbook;
  private GLib.List<string> _e_contacts;
  private GLib.List<Gee.HashMap<string, Value?>> _contacts;
  E.SourceGroup _source_group;
  E.Source _source;

  public Backend ()
    {
      this._contacts = new GLib.List<Gee.HashMap<string, Value?>> ();
      this._e_contacts = new GLib.List<string> ();
   }

  public void add_contact (owned Gee.HashMap<string, Value?> c)
    {
      this._contacts.prepend (c);
    }

  public async void update_contact (int contact_pos,
      owned Gee.HashMap<string, Value?> updated_data)
    {
      var uid = this._e_contacts.nth_data (contact_pos);
      E.Contact contact;
      try
        {
          yield this._addressbook.get_contact (uid, out contact);
          this._set_contact_fields (contact, updated_data);
          yield this._addressbook.modify_contact (contact);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Couldn't update contact\n");
        }
    }

  public async void remove_contact (int contact_pos)
    {
      var uid = this._e_contacts.nth_data (contact_pos);
      E.Contact contact;
      try
        {
          yield this._addressbook.get_contact (uid, out contact);
          yield this._addressbook.remove_contact (contact);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Couldn't remove contact\n");
        }
    }

  public void reset ()
    {
      this._contacts = new GLib.List<Gee.HashMap<string, Value?>> ();
      this._e_contacts = new GLib.List<string> ();
    }

  /* Create a temporary addressbook */
  public void set_up ()
    {
      try
        {
          this._prepare_source ();
          this._addressbook = new BookClient (this._source);
          this._addressbook.open_sync (false, null);
          this._addressbook_name =
            this._addressbook.get_source ().peek_name ();
          Environment.set_variable ("FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS",
                                    this._addressbook_name, true);
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Unable to create test data: %s\n", e.message);
        }
    }

  private void _prepare_source ()
    {
      var base_uri = "local:";
      this._source_group = new E.SourceGroup ("Test", base_uri);

      this._source = new E.Source ("Test", this.address_book_uri);
      if (this._source_group.add_source (this._source, -1))
        {
          try
            {
              SourceList sl;
              BookClient.get_sources (out sl);
              sl.add_group (this._source_group, 0);
              sl.sync ();
            }
          catch (GLib.Error e)
            {
              // XXX
            }
        }
    }

  public async void commit_contacts_to_addressbook ()
    {
      this._contacts.reverse ();
      foreach (var c in this._contacts)
        {
          E.Contact contact = new E.Contact ();

          this._set_contact_fields (contact, c);

          try
            {
              string added_uid;
              yield this._addressbook.add_contact (contact,
                  out added_uid);
              this._e_contacts.prepend ((owned) added_uid);
            }
          catch (GLib.Error e)
            {
              GLib.warning ("Couldn't add contact: %s\n",
                  e.message);
            }
        }
        this._e_contacts.reverse ();
    }

  private void _set_contact_fields (E.Contact contact,
                                    Gee.HashMap<string, Value?> c)
    {
      bool added_contact_name = false;
      E.ContactName contact_name = new E.ContactName ();
      string contact_field_name = "contact_name";
      int min_len = contact_field_name.length;

      foreach (var k in c.keys)
        {
          if (k.length > min_len && k.slice(0, min_len) == contact_field_name)
            {
              var v = c.get (k).get_string ();
              if (k.index_of ("family") >= 0)
                {
                  contact_name.family = v;
                }
              else if (k.index_of ("given") >= 0)
                {
                  contact_name.given = v;
                }
              else if (k.index_of ("additional") >= 0)
                {
                  contact_name.additional = v;
                }
              else if (k.index_of ("prefixes") >= 0)
                {
                  contact_name.prefixes = v;
                }
              else if (k.index_of ("suffixes") >= 0)
                {
                  contact_name.suffixes = v;
                }

              added_contact_name = true;
            }
          else if (k == "avatar")
            {
              var v = c.get (k).get_string ();
              uint8[] photo_content;
              var file = File.new_for_path (v);

              try
                {
                  file.load_contents (null, out photo_content);

                  var cp = new ContactPhoto ();
                  cp.type = ContactPhotoType.INLINED;
                  cp.set_inlined (photo_content);

                  contact.set (E.Contact.field_id ("photo"), cp);
                }
              catch (GLib.Error e)
                {
                  GLib.warning ("\n\nCan't load avatar %s: %s\n\n", v,
                      e.message);
                }
            }
          else if (k == "im_addresses")
            {
              var v = c.get (k).get_string ();
              var addresses = this._parse_addrs (v);
              foreach (var addr in addresses.keys)
                {
                  var proto = addresses.get (addr);
                  contact.set (E.Contact.field_id (proto), addr);
                }
            }
          else if (k == Edsf.Persona.address_fields[0])
            {
              var pa = (PostalAddress) c.get (k).get_object ();
              var address = new E.ContactAddress ();
              address.po = pa.po_box;
              address.ext = pa.extension;
              address.street = pa.street;
              address.locality = pa.locality;
              address.region = pa.region;
              address.code = pa.postal_code;
              address.country = pa.country;
              address.address_format = pa.address_format;

              contact.set (E.Contact.field_id (k), address);
           }
          else
            {
              var v = c.get (k).get_string ();
              contact.set (E.Contact.field_id (k), v);
            }
        }
      if (added_contact_name)
        {
          contact.set (E.Contact.field_id ("name"), contact_name);
        }
    }

  public void tear_down ()
    {
      Environment.set_variable ("FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS",
          "", true);

      try
        {
          var ret = this._addressbook.remove_sync (null);
          if (ret == false)
            {
              GLib.warning ("remove() addressbook returned false on %s\n",
                                  this._addressbook_name);
            }

          this._addressbook = null;
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Unable to remove addressbook %s because: %s\n",
                              this._addressbook_name, e.message);
        }
    }

  private Gee.HashMap<string, string> _parse_addrs (string addr_s)
    {
      Gee.HashMap<string, string> ret = new Gee.HashMap<string, string> ();
      string[] im_addrs = addr_s.split (",");

      foreach (var a in im_addrs)
        {
          string[] info = a.split ("#");
          string proto = info[0];
          string addr = info[1];

          ret.set ((owned) addr, (owned) proto);
        }

      return ret;
    }
}
