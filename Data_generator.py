import pandas as pd
import numpy as np

""" 
Generalized script to generate power production data for any nordic market
The script generates hourly data for solar and wind power production, as well as demand
The data is generated for each season (spring, summer, autumn, winter) over a two-day period
The script saves the generated data to a CSV file

Created in part with ChatGPT and CoPiilot AI
Trends in the data are based on general patterns observed in the DK1 and DK2 power market
"""
 

# === Constants ===
MARKET_NAME = "Generic Market"  # Replace with the market's name (e.g., "UK", "Faroe Islands")
MAX_SOLAR = 14500  # Replace with the maximum solar capacity in MW
MAX_WIND = 26900  # Replace with the maximum wind capacity in MW
AVERAGE_DEMAND = 48000  # Replace with the average demand in MW

# Seasonal solar and wind production factors to simulate seasonal variations
SEASONAL_SOLAR_FACTORS = {
    "Spring": 0.7,  # Adjust solar production for spring
    "Summer": 1.0,  # Peak solar production in summer
    "Autumn": 0.5,  # Lower production in autumn
    "Winter": 0.3   # Minimal solar production in winter
}

SEASONAL_WIND_FACTORS = {
    "Spring": (0.4, 0.7),  # Lower wind production
    "Summer": (0.4, 0.7),  # Lower wind production
    "Autumn": (0.7, 1.0),  # Higher wind production
    "Winter": (0.7, 1.0)   # Higher wind production
}

SEASONS = ["Spring", "Summer", "Autumn", "Winter"]
HOURS = list(range(24))  # 24 hours in a day
DAYS_PER_SEASON = 2  # Number of days of data to generate per season

# === Generate data ===
data = []
for season in SEASONS:
    for day in range(DAYS_PER_SEASON):
        for hour in HOURS:
            # Solar production
            solar_factor = max(0, np.sin((hour - 6) * np.pi / 12))  # Diurnal curve
            solar_mw = solar_factor * MAX_SOLAR * np.random.uniform(0.8, 1.0) * SEASONAL_SOLAR_FACTORS.get(season, 0)
            
            # Wind production
            wind_min, wind_max = SEASONAL_WIND_FACTORS.get(season, (0.4, 0.7))
            wind_factor = np.random.uniform(wind_min, wind_max)
            wind_mw = wind_factor * MAX_WIND * np.random.uniform(0.7, 1.0)
            
            # Demand
            demand = AVERAGE_DEMAND * np.random.uniform(0.95, 1.05)
            
            # Append to data
            data.append({
                "Hour": hour + (day * 24),
                "Solar - Actual Aggregated [MW]": round(solar_mw, 2),
                "Wind - Actual Aggregated [MW]": round(wind_mw, 2),
                "Demand [MW]": round(demand, 2),
                "Season": season
            })

# === Create DataFrame ===
power_data = pd.DataFrame(data)

# === Save to CSV ===
output_file_path = f"{MARKET_NAME.replace(' ', '_')}_Power_Production.csv"
power_data.to_csv(output_file_path, index=False)

print(f"Dataset for {MARKET_NAME} saved as '{output_file_path}'.")
