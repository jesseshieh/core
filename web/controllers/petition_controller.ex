defmodule Core.PetitionController do
  use Core.Web, :controller

  def get(conn, params = %{"petition" => petition}) do
    object = Cosmic.get(petition)
    render_petition(conn, params, object)
  end

  # Match petition exists and is proper brand
  defp render_petition(conn, params, object = %{"metadata" => %{
    "brands" => brands,
    "visibility" => visibility
  }}) do
    brand = Keyword.get(GlobalOpts.get(conn, params), :brand)

    if Enum.member?(brands, brand) do
      case visibility do
        "Draft" -> do_render_draft(conn, params, object)
        "Published" -> do_render_petition(conn, params, object)
      end
    else
      redirect_home(conn, params)
    end
  end

  # Match petition is nil
  defp render_petition(conn, params, nil) do
    render conn, "404.html", GlobalOpts.get(conn, params)
  end

  defp do_render_draft(conn, params, object) do
    if Map.has_key?(params, "draft") do
      do_render_petition(conn, params, object)
    else
      redirect_home(conn, params)
    end
  end

  # Extract and render petition
  defp do_render_petition(conn, params, %{
    "slug" => slug,
    "title" => title,
    "content" => content,
    "metadata" => %{
      "sign_button_text" => sign_button_text,
      "post_sign_text" => post_sign_text,
      "background_image" => %{
        "imgix_url" => background_image
      },
    }
  }) do

    render conn, "petition.html",
      [slug: slug, title: title, content: content, sign_button_text: sign_button_text,
       post_sign_text: post_sign_text, background_image: background_image,
       no_footer: true, signed: false] ++ GlobalOpts.get(conn, params)
  end

  def post(conn, params = %{"petition" => petition, "name" => name, "email" => email, "zip" => zip}) do
    global_opts = GlobalOpts.get(conn, params)

    %{"slug" => slug,
      "title" => title,
      "content" => content,
      "metadata" => %{
        "sign_button_text" => sign_button_text,
        "post_sign_text" => post_sign_text,
        "tweet_template" => tweet_template,
        "background_image" => %{
          "imgix_url" => background_image
        }
      }
    } = Cosmic.get(petition)

    url = "https://#{conn.host}/petition/#{slug}"
    twitter_query = URI.encode_query([text: tweet_template, url: url])
    twitter_href = "https://twitter.com/intent/tweet?#{twitter_query}"

    fb_query = URI.encode_query([u: url])
    fb_href = "https://www.facebook.com/sharer/sharer.php?#{fb_query}&amp;src=sdkpreparse"

    # Get person's id / create them
    names = name |> String.trim() |> String.split(" ")
    first_name = List.first(names)
    last_name = if length(names) > 1 do
      List.last(names)
    else
      ""
    end

    %{"id" => id} = Nb.People.push(%{
      "email" => email,
      "first_name" => first_name,
      "last_name" => last_name,
      "mailing_address" => %{"zip" => zip}
    })

    # Add the petition signed tag
    brand = Keyword.get(global_opts, :brand)
    source = case brand do
      "jd" -> "Justice Democrats"
      "bnc" -> "Brand New Congress"
    end
    tag = "Action: Signed Petition: #{source}: #{title}"

    Nb.People.add_tags(id, tag)

    render conn, "petition.html",
      [slug: slug, title: title, content: content, sign_button_text: sign_button_text,
       post_sign_text: post_sign_text, background_image: background_image,
       twitter_href: twitter_href, fb_href: fb_href, no_footer: true, url: url,
       signed: true] ++ GlobalOpts.get(conn, params)
  end

  def redirect_home(conn, params) do
    url = case (conn |> GlobalOpts.get(params) |> Keyword.get(:brand)) do
      "jd" -> "https://justicedemocrats.com"
      "bnc" -> "https://brandnewcongress.org"
    end
    redirect(conn, external: url)
  end
end
