export async function fetchData(payload) {
  const API_URL = "http://127.0.0.1:8080/execute";
  try {
    const response = await fetch(API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!response.ok) throw new Error(`HTTP error: ${response.status}`);
    const data = await response.json();
    if (data.error) throw new Error(data.error);
    return data.result;
  } catch (error) {
    console.error("Error fetching data:", error);
    return [];
  }
}
