import 'package:flutter/material.dart';
import '../services/places_service.dart';

class SearchDestination extends StatefulWidget {
  final Function(double lat, double lng, String name) onDestinationSelected;
  final double? userLat;
  final double? userLng;

  const SearchDestination({
    super.key,
    required this.onDestinationSelected,
    this.userLat,
    this.userLng,
  });

  @override
  State<SearchDestination> createState() => _SearchDestinationState();
}

class _SearchDestinationState extends State<SearchDestination> {
  final TextEditingController _searchController = TextEditingController();
  final PlacesService _placesService = PlacesService();
  List<PlaceResult> _searchResults = [];
  List<PlaceResult> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _placesService.getCommonPlaces(
        userLat: widget.userLat,
        userLng: widget.userLng,
      );
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Error loading suggestions: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final results = await _placesService.searchPlaces(
        query: query,
        userLat: widget.userLat,
        userLng: widget.userLng,
        limit: 8,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectPlace(PlaceResult place) {
    widget.onDestinationSelected(
      place.latitude,
      place.longitude,
      place.name,
    );
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search places in Nigeria...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF008751), size: 24),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _showSuggestions = true;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF008751), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF008751), width: 2.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    _showSuggestions = true;
                  }
                });
                _searchLocation(value);
              },
              onTap: () {
                if (_searchController.text.isEmpty && _suggestions.isNotEmpty) {
                  setState(() {
                    _showSuggestions = true;
                  });
                }
              },
            ),
          ),

          // Loading indicator
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF008751),
                  strokeWidth: 2.5,
                ),
              ),
            ),

          // Search Results or Suggestions
          if (_searchResults.isNotEmpty || _showSuggestions)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _searchResults.isNotEmpty ? _searchResults.length : _suggestions.length,
                itemBuilder: (context, index) {
                  final place = _searchResults.isNotEmpty
                      ? _searchResults[index]
                      : _suggestions[index];
                  
                  return ListTile(
                    leading: Icon(
                      place.placeType == 'place' ? Icons.location_city : Icons.location_on,
                      color: const Color(0xFF008751),
                      size: 22,
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: place.description != null
                        ? Text(
                            place.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () {
                      _selectPlace(place);
                    },
                  );
                },
              ),
            ),

          // Empty state message
          if (_searchController.text.isNotEmpty && _searchResults.isEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No places found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
