const { chromium } = require('playwright');
const handle = process.argv[2] || 'vikamomplants';

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const ctx = await browser.newContext({
    locale: 'ru-RU',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
    ignoreHTTPSErrors: true,
  });
  const page = await ctx.newPage();
  let out = { handle };
  try {
    await page.goto('https://www.instagram.com/', { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForTimeout(1500);
    const data = await page.evaluate(async (h) => {
      const r = await fetch(`https://www.instagram.com/api/v1/users/web_profile_info/?username=${h}`, {
        headers: { 'x-ig-app-id': '936619743392459', 'x-requested-with': 'XMLHttpRequest' },
        credentials: 'include',
      });
      return { status: r.status, body: await r.text() };
    }, handle);
    out.apiStatus = data.status;
    try {
      const j = JSON.parse(data.body);
      const u = j.data && j.data.user;
      if (u) {
        out.profile = {
          full_name: u.full_name,
          username: u.username,
          biography: u.biography,
          category: u.category_name,
          followers: u.edge_followed_by && u.edge_followed_by.count,
          following: u.edge_follow && u.edge_follow.count,
          posts: u.edge_owner_to_timeline_media && u.edge_owner_to_timeline_media.count,
          is_private: u.is_private,
          is_business: u.is_business_account,
          external_url: u.external_url,
        };
        const edges = (u.edge_owner_to_timeline_media && u.edge_owner_to_timeline_media.edges) || [];
        out.recent = edges.slice(0, 12).map(e => {
          const n = e.node;
          const cap = n.edge_media_to_caption && n.edge_media_to_caption.edges[0];
          return {
            type: n.__typename,
            likes: n.edge_liked_by && n.edge_liked_by.count,
            comments: n.edge_media_to_comment && n.edge_media_to_comment.count,
            caption: cap ? cap.node.text.slice(0, 300) : '',
          };
        });
      } else {
        out.raw = data.body.slice(0, 600);
      }
    } catch (e) {
      out.parseError = String(e).slice(0, 200);
      out.raw = data.body.slice(0, 600);
    }
  } catch (e) {
    out.error = String(e).slice(0, 300);
  }
  await browser.close();
  console.log(JSON.stringify(out, null, 2));
})();
