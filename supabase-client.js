/* =========================================================
   NEXUS — Supabase client
   Fill in the two values below after you create your Supabase
   project (Project Settings -> API). Both are safe to expose
   publicly — access is controlled by Row Level Security, not
   by hiding this key.
   ========================================================= */
const SUPABASE_URL = "https://dowoepbkiqohyfvjlnbi.supabase.co"; // e.g. https://abcxyz.supabase.co
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRvd29lcGJraXFvaHlmdmpsbmJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjM1NjksImV4cCI6MjEwMjc5OTU2OX0.UiW5LOnhmeyoIh4XUNkJwAd-HJ-uhhCkni5_X_hWyxo";

// Loaded from CDN in every page via:
// <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
const nexus = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
