#ifndef PARALLEL_FOR_HPP
#define PARALLEL_FOR_HPP

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <thread>
#include <vector>

template <typename Index, typename Func>
void parallel_for(Index begin, Index end, Func fn) {
	const Index count = end - begin;
	if (count <= 0)
		return;

#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
	// Web build without pthread support: run serially.
	for (Index i = begin; i < end; ++i) {
		fn(i);
	}
#else
	unsigned int workers = std::thread::hardware_concurrency();
	if (workers == 0)
		workers = 4;

	// Avoid too many threads for small workloads.
	workers = std::min<unsigned int>(workers, static_cast<unsigned int>(count));

	std::atomic<Index> next{ begin };
	std::vector<std::thread> threads;
	threads.reserve(workers);

	for (unsigned int t = 0; t < workers; ++t) {
		threads.emplace_back([&]() {
			while (true) {
				Index i = next.fetch_add(1, std::memory_order_relaxed);
				if (i >= end)
					break;
				fn(i);
			}
		});
	}

	for (auto &thread : threads) {
		thread.join();
	}
#endif
}

template <typename Index, typename Func>
void parallel_for_chunks(Index begin, Index end, Index grainSize, Func fn) {
	const Index count = end - begin;
	if (count <= 0)
		return;

#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
	// Web build without pthread support: run serially.
	for (Index i = begin; i < end; ++i) {
		fn(i);
	}
#else
	unsigned int workers = std::thread::hardware_concurrency();
	if (workers == 0)
		workers = 4;

	Index chunks = (count + grainSize - 1) / grainSize;
	workers = std::min<unsigned int>(workers, static_cast<unsigned int>(chunks));

	std::atomic<Index> nextChunk{ 0 };
	std::vector<std::thread> threads;
	threads.reserve(workers);

	for (unsigned int t = 0; t < workers; ++t) {
		threads.emplace_back([&]() {
			while (true) {
				Index chunk = nextChunk.fetch_add(1, std::memory_order_relaxed);
				if (chunk >= chunks)
					break;

				Index chunkBegin = begin + chunk * grainSize;
				Index chunkEnd = std::min(end, chunkBegin + grainSize);

				for (Index i = chunkBegin; i < chunkEnd; ++i) {
					fn(i);
				}
			}
		});
	}

	for (auto &thread : threads) {
		thread.join();
	}
#endif
}

#endif
