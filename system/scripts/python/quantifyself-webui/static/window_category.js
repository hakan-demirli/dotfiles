// window_category.js
export async function getWindowCategories() {
  try {
    const response = await fetch("window_categories.json"); // Path to your JSON file
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const categories = await response.json();
    return categories;
  } catch (error) {
    console.error("Error fetching window categories:", error);
    // Handle error appropriately - perhaps return a default set
    return [];
  }
}
