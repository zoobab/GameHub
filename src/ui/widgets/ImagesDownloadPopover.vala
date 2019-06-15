/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;
using Granite;

using GameHub.Data;
using GameHub.Data.Providers;

namespace GameHub.UI.Widgets
{
	class ImagesDownloadPopover: Popover
	{
		private const int CARD_WIDTH_MIN = 180;
		private const int CARD_WIDTH_MAX = 520;
		private const float CARD_RATIO = 0.467f; // 460x215

		public Game game { get; construct; }

		public FileChooserEntry entry { get; construct; }

		private Stack stack;
		private Spinner spinner;
		private Granite.Widgets.AlertView no_images_alert;
		private ScrolledWindow images_scroll;
		private Box images;

		private bool images_load_started = false;

		public ImagesDownloadPopover(Game game, FileChooserEntry entry, MenuButton button)
		{
			Object(game: game, relative_to: button, entry: entry);
			button.popover = this;
			position = PositionType.LEFT;

			button.clicked.connect(load_images);

			game.notify["name"].connect(() => {
				images.foreach(i => i.destroy());
				images_load_started = false;
				stack.visible_child = spinner;
			});
		}

		construct
		{
			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.interpolate_size = true;

			spinner = new Spinner();
			spinner.halign = spinner.valign = Align.CENTER;
			spinner.set_size_request(32, 32);
			spinner.margin = 16;
			spinner.start();

			no_images_alert = new Granite.Widgets.AlertView(_("No images"), _("There are no images found for this game\nMake sure game name is correct"), "dialog-information");
			no_images_alert.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			images_scroll = new ScrolledWindow(null, null);
			images_scroll.set_size_request(520, 380);

			images = new Box(Orientation.VERTICAL, 0);
			images.margin = 4;

			images_scroll.add(images);

			stack.add(spinner);
			stack.add(no_images_alert);
			stack.add(images_scroll);

			spinner.show();
			stack.visible_child = spinner;

			child = stack;

			stack.show();
		}

		private void load_images()
		{
			if(images_load_started) return;
			images_load_started = true;

			load_images_async.begin();
		}

		private async void load_images_async()
		{
			foreach(var src in ImageProviders)
			{
				if(!src.enabled) continue;
				var result = yield src.images(game);

				if(result != null && result.images != null && result.images.size > 0)
				{
					if(images.get_children().length() > 0)
					{
						var separator = new Separator(Orientation.HORIZONTAL);
						separator.margin = 4;
						separator.margin_bottom = 0;
						images.add(separator);
					}

					var header_hbox = new Box(Orientation.HORIZONTAL, 8);
					header_hbox.margin_start = header_hbox.margin_end = 4;

					var header = new HeaderLabel(src.name);
					header.hexpand = true;

					header_hbox.add(header);

					if(result.url != null)
					{
						var link = new Button.from_icon_name("web-browser-symbolic");
						link.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
						link.tooltip_text = result.url;
						link.clicked.connect(() => {
							Utils.open_uri(result.url);
						});
						header_hbox.add(link);
					}

					images.add(header_hbox);

					var flow = new FlowBox();
					flow.activate_on_single_click = true;
					flow.homogeneous = true;
					flow.min_children_per_line = 1;
					flow.selection_mode = SelectionMode.SINGLE;

					flow.child_activated.connect(item => {
						entry.select_file_path(((ImageItem) item).image.url);
						#if GTK_3_22
						popdown();
						#else
						hide();
						#endif
					});

					foreach(var img in result.images)
					{
						var item = new ImageItem(img);
						flow.add(item);
						if(img.url == game.image)
						{
							flow.select_child(item);
							item.grab_focus();
						}
					}

					images.add(flow);
				}
			}

			if(images.get_children().length() > 0)
			{
				images_scroll.show_all();
				stack.visible_child = images_scroll;
			}
			else
			{
				no_images_alert.show_all();
				stack.visible_child = no_images_alert;
			}
		}

		private class ImageItem: FlowBoxChild
		{
			public ImagesProvider.Image image { get; construct; }

			public ImageItem(ImagesProvider.Image image)
			{
				Object(image: image);
			}

			construct
			{
				margin = 0;

				var card = new Frame(null);
				card.sensitive = false;
				card.get_style_context().add_class(Granite.STYLE_CLASS_CARD);
				card.get_style_context().add_class("gamecard");
				card.get_style_context().add_class("static");
				card.shadow_type = ShadowType.NONE;
				card.margin = 4;

				card.tooltip_markup = image.description;

				var img = new AutoSizeImage();
				img.set_constraint(CARD_WIDTH_MIN, CARD_WIDTH_MAX, CARD_RATIO);
				img.load(image.url, "image");

				card.add(img);

				child = card;
				show_all();
			}
		}
	}
}